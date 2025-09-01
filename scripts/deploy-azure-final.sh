#!/bin/bash

# Simple Smart Azure Deployment
# Checks resource availability before creating

set -e

# Configuration
RESOURCE_GROUP="ai-receptionist-simple"
LOCATION=""
APP_NAME="ai-receptionist-$(date +%s | tail -c 6)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "🚀 Simple Smart Azure Deployment"
echo "================================"
echo ""

# Find working location
find_working_location() {
    local locations=("centralus" "westus2" "eastus" "westeurope" "eastus2")
    
    for loc in "${locations[@]}"; do
        log_info "Testing location: $loc"
        
        # Test PostgreSQL availability
        if az postgres flexible-server list-skus --location $loc --output tsv >/dev/null 2>&1; then
            log_success "PostgreSQL available in $loc"
            LOCATION=$loc
            return 0
        else
            log_warning "PostgreSQL not available in $loc"
        fi
    done
    
    log_error "No suitable location found"
    return 1
}

# Check if resource exists
resource_exists() {
    local resource_type=$1
    local name=$2
    
    case $resource_type in
        "group")
            az group exists --name $name --output tsv 2>/dev/null | grep -q "true"
            ;;
        "postgres")
            az postgres flexible-server show --name $name --resource-group $RESOURCE_GROUP --output tsv >/dev/null 2>&1
            ;;
        "redis")
            az redis show --name $name --resource-group $RESOURCE_GROUP --output tsv >/dev/null 2>&1
            ;;
        "webapp")
            az webapp show --name $name --resource-group $RESOURCE_GROUP --output tsv >/dev/null 2>&1
            ;;
    esac
}

# Create resource group
create_resource_group() {
    if resource_exists "group" $RESOURCE_GROUP; then
        log_success "Resource group $RESOURCE_GROUP already exists"
        # Get existing location
        LOCATION=$(az group show --name $RESOURCE_GROUP --query location --output tsv)
        log_info "Using existing location: $LOCATION"
    else
        log_info "Creating resource group in $LOCATION..."
        az group create --name $RESOURCE_GROUP --location $LOCATION --output table
        log_success "Resource group created"
    fi
}

# Create PostgreSQL
create_postgres() {
    local server_name="ai-receptionist-db-$APP_NAME"
    
    if resource_exists "postgres" $server_name; then
        log_success "PostgreSQL server already exists"
        return 0
    fi
    
    log_info "Creating PostgreSQL server..."
    local db_password=$(openssl rand -base64 32)
    echo $db_password > /tmp/db_password_$APP_NAME.txt
    
    az postgres flexible-server create \
        --resource-group $RESOURCE_GROUP \
        --name $server_name \
        --location $LOCATION \
        --admin-user receptionist_admin \
        --admin-password $db_password \
        --sku-name Standard_B1ms \
        --tier Burstable \
        --version 14 \
        --storage-size 32 \
        --public-access 0.0.0.0 \
        --yes
    
    # Create database
    az postgres flexible-server db create \
        --resource-group $RESOURCE_GROUP \
        --server-name $server_name \
        --database-name ai_receptionist
    
    log_success "PostgreSQL server created: $server_name"
    echo $server_name > /tmp/postgres_server_$APP_NAME.txt
}

# Create Redis
create_redis() {
    local redis_name="ai-receptionist-redis-$APP_NAME"
    
    if resource_exists "redis" $redis_name; then
        log_success "Redis cache already exists"
        return 0
    fi
    
    log_info "Creating Redis cache..."
    
    az redis create \
        --location $LOCATION \
        --name $redis_name \
        --resource-group $RESOURCE_GROUP \
        --sku Basic \
        --vm-size c0
    
    log_success "Redis cache created: $redis_name"
    echo $redis_name > /tmp/redis_name_$APP_NAME.txt
}

# Create web app
create_webapp() {
    local plan_name="ai-receptionist-plan-$APP_NAME"
    local webapp_name="ai-receptionist-web-$APP_NAME"
    
    # Create App Service plan if it doesn't exist
    if ! az appservice plan show --name $plan_name --resource-group $RESOURCE_GROUP >/dev/null 2>&1; then
        log_info "Creating App Service plan..."
        az appservice plan create \
            --name $plan_name \
            --resource-group $RESOURCE_GROUP \
            --location $LOCATION \
            --sku F1 \
            --is-linux
    else
        log_success "App Service plan already exists"
    fi
    
    # Create web app if it doesn't exist
    if ! resource_exists "webapp" $webapp_name; then
        log_info "Creating web app..."
        az webapp create \
            --name $webapp_name \
            --resource-group $RESOURCE_GROUP \
            --plan $plan_name \
            --runtime "NODE:20-lts"
        
        # Configure GitHub deployment
        az webapp deployment source config \
            --name $webapp_name \
            --resource-group $RESOURCE_GROUP \
            --repo-url https://github.com/danipopa/ai-receptionist \
            --branch main \
            --manual-integration
            
        log_success "Web app created: $webapp_name"
    else
        log_success "Web app already exists"
    fi
    
    echo $webapp_name > /tmp/webapp_name_$APP_NAME.txt
}

# Main deployment
main() {
    # Step 1: Find working location
    if [[ -z "$LOCATION" ]]; then
        log_info "Finding best Azure location..."
        find_working_location
        if [[ $? -ne 0 ]]; then
            log_error "Failed to find suitable location"
            exit 1
        fi
    fi
    
    # Step 2: Create resource group
    create_resource_group
    
    # Step 3: Create PostgreSQL
    create_postgres
    
    # Step 4: Create Redis
    create_redis
    
    # Step 5: Create web app
    create_webapp
    
    # Success summary
    local postgres_server=$(cat /tmp/postgres_server_$APP_NAME.txt 2>/dev/null || echo "Unknown")
    local redis_name=$(cat /tmp/redis_name_$APP_NAME.txt 2>/dev/null || echo "Unknown")
    local webapp_name=$(cat /tmp/webapp_name_$APP_NAME.txt 2>/dev/null || echo "Unknown")
    
    echo ""
    log_success "Deployment completed!"
    echo ""
    echo "🎉 AI Receptionist Deployed!"
    echo "=========================="
    echo ""
    echo "📍 Location: $LOCATION"
    echo "🗂️  Resource Group: $RESOURCE_GROUP"
    echo "🐘 PostgreSQL: $postgres_server"
    echo "🔴 Redis: $redis_name"
    echo "🌐 Web App: https://$webapp_name.azurewebsites.net"
    echo ""
    echo "🔧 Management:"
    echo "  View resources: az resource list --resource-group $RESOURCE_GROUP --output table"
    echo "  Delete all: az group delete --name $RESOURCE_GROUP --yes"
    echo ""
    echo "💰 Estimated monthly cost: ~$50-150"
}

# Confirmation
echo "This will deploy AI Receptionist to Azure."
echo "Features:"
echo "  ✅ Checks if resources already exist"
echo "  ✅ Continues from where it left off"
echo "  ✅ Auto-finds best Azure region"
echo "  ✅ Creates only missing resources"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 1
fi

main
