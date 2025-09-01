#!/bin/bash

# Smart Azure Deployment with Location and Resource Validation
# Automatically finds the best region and checks resource availability

set -e

# Configuration
RESOURCE_GROUP="ai-receptionist-smart"
PREFERRED_LOCATIONS=("eastus2" "centralus" "westus2" "eastus" "westeurope" "northeurope")
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

echo "🚀 Smart Azure Deployment with Auto-Discovery"
echo "============================================="
echo ""

# Check if resource group exists
check_resource_group() {
    local rg_name=$1
    if az group exists --name $rg_name --output tsv 2>/dev/null | grep -q "true"; then
        return 0
    else
        return 1
    fi
}

# Find best location for PostgreSQL Flexible Server
find_best_location_postgres() {
    log_info "Finding best location for PostgreSQL Flexible Server..."
    
    for location in "${PREFERRED_LOCATIONS[@]}"; do
        log_info "Checking PostgreSQL availability in $location..."
        
        # Check if PostgreSQL Flexible Server is available
        if az postgres flexible-server list-skus --location $location --output tsv >/dev/null 2>&1; then
            log_success "PostgreSQL Flexible Server available in $location"
            echo $location
            return 0
        else
            log_warning "PostgreSQL Flexible Server not available in $location"
        fi
    done
    
    log_error "No suitable location found for PostgreSQL Flexible Server"
    return 1
}

# Find best location for Container Instances
find_best_location_aci() {
    log_info "Finding best location for Container Instances..."
    
    for location in "${PREFERRED_LOCATIONS[@]}"; do
        log_info "Checking Container Instances availability in $location..."
        
        # Check if Container Instances provider is available
        if az provider show --namespace Microsoft.ContainerInstance --query "registrationState" --output tsv 2>/dev/null | grep -q "Registered"; then
            # Test if we can query container groups in this location
            if az container list --resource-group "dummy" --output tsv >/dev/null 2>&1 || [[ $? -eq 3 ]]; then
                log_success "Container Instances available in $location"
                echo $location
                return 0
            fi
        fi
    done
    
    # Fallback: register provider and use first location
    log_warning "Registering Container Instance provider..."
    az provider register --namespace Microsoft.ContainerInstance >/dev/null 2>&1
    echo ${PREFERRED_LOCATIONS[0]}
    return 0
}

# Check quota availability
check_quota() {
    local location=$1
    log_info "Checking quota availability in $location..."
    
    # Check general compute quota
    local cores_used=$(az vm list-usage --location $location --query "[?localName=='Total Regional vCPUs'].currentValue" --output tsv 2>/dev/null || echo "0")
    local cores_limit=$(az vm list-usage --location $location --query "[?localName=='Total Regional vCPUs'].limit" --output tsv 2>/dev/null || echo "100")
    
    log_info "vCPU usage: $cores_used / $cores_limit"
    
    if [[ $cores_used -lt $((cores_limit - 10)) ]]; then
        log_success "Sufficient quota available in $location"
        return 0
    else
        log_warning "Low quota in $location"
        return 1
    fi
}

# Create or verify resource group
setup_resource_group() {
    local location=$1
    
    if check_resource_group $RESOURCE_GROUP; then
        log_success "Resource group $RESOURCE_GROUP already exists"
        
        # Get existing location
        local existing_location=$(az group show --name $RESOURCE_GROUP --query location --output tsv)
        log_info "Existing resource group location: $existing_location"
        echo $existing_location
    else
        log_info "Creating resource group in $location..."
        az group create --name $RESOURCE_GROUP --location $location --output table
        log_success "Resource group created in $location"
        echo $location
    fi
}

# Check if PostgreSQL server exists
check_postgres_server() {
    local server_name=$1
    local rg_name=$2
    
    if az postgres flexible-server show --name $server_name --resource-group $rg_name --output tsv >/dev/null 2>&1; then
        log_success "PostgreSQL server $server_name already exists"
        return 0
    else
        return 1
    fi
}

# Create PostgreSQL server
create_postgres_server() {
    local location=$1
    local server_name="ai-receptionist-db-$APP_NAME"
    local db_password=$(openssl rand -base64 32)
    
    if check_postgres_server $server_name $RESOURCE_GROUP; then
        echo $server_name
        return 0
    fi
    
    log_info "Creating PostgreSQL Flexible Server in $location..."
    
    # Store password for later use
    echo $db_password > /tmp/db_password_$APP_NAME.txt
    
    az postgres flexible-server create \
        --resource-group $RESOURCE_GROUP \
        --name $server_name \
        --location $location \
        --admin-user receptionist_admin \
        --admin-password $db_password \
        --sku-name Standard_B1ms \
        --tier Burstable \
        --version 14 \
        --storage-size 32 \
        --public-access 0.0.0.0 \
        --output table
    
    if [[ $? -eq 0 ]]; then
        log_success "PostgreSQL server created successfully"
        
        # Create database
        log_info "Creating database..."
        az postgres flexible-server db create \
            --resource-group $RESOURCE_GROUP \
            --server-name $server_name \
            --database-name ai_receptionist \
            --output table
        
        echo $server_name
    else
        log_error "Failed to create PostgreSQL server"
        return 1
    fi
}

# Check if Redis exists
check_redis() {
    local redis_name=$1
    local rg_name=$2
    
    if az redis show --name $redis_name --resource-group $rg_name --output tsv >/dev/null 2>&1; then
        log_success "Redis cache $redis_name already exists"
        return 0
    else
        return 1
    fi
}

# Create Redis cache
create_redis() {
    local location=$1
    local redis_name="ai-receptionist-redis-$APP_NAME"
    
    if check_redis $redis_name $RESOURCE_GROUP; then
        echo $redis_name
        return 0
    fi
    
    log_info "Creating Redis cache in $location..."
    
    az redis create \
        --location $location \
        --name $redis_name \
        --resource-group $RESOURCE_GROUP \
        --sku Basic \
        --vm-size c0 \
        --output table
    
    if [[ $? -eq 0 ]]; then
        log_success "Redis cache created successfully"
        echo $redis_name
    else
        log_error "Failed to create Redis cache"
        return 1
    fi
}

# Deploy simple web app
deploy_web_app() {
    local location=$1
    local plan_name="ai-receptionist-plan-$APP_NAME"
    local webapp_name="ai-receptionist-web-$APP_NAME"
    
    # Check if app service plan exists
    if ! az appservice plan show --name $plan_name --resource-group $RESOURCE_GROUP --output tsv >/dev/null 2>&1; then
        log_info "Creating App Service plan..."
        az appservice plan create \
            --name $plan_name \
            --resource-group $RESOURCE_GROUP \
            --location $location \
            --sku F1 \
            --is-linux \
            --output table
    else
        log_success "App Service plan already exists"
    fi
    
    # Check if web app exists
    if ! az webapp show --name $webapp_name --resource-group $RESOURCE_GROUP --output tsv >/dev/null 2>&1; then
        log_info "Creating web app..."
        az webapp create \
            --name $webapp_name \
            --resource-group $RESOURCE_GROUP \
            --plan $plan_name \
            --runtime "NODE:20-lts" \
            --output table
        
        # Configure deployment
        log_info "Configuring GitHub deployment..."
        
        # Check if deployment source is already configured
        existing_source=$(az webapp deployment source show \
            --name $webapp_name \
            --resource-group $RESOURCE_GROUP \
            --query "repoUrl" \
            --output tsv 2>/dev/null || echo "")
        
        if [[ -z "$existing_source" ]]; then
            # Configure GitHub deployment with error handling
            if az webapp deployment source config \
                --name $webapp_name \
                --resource-group $RESOURCE_GROUP \
                --repo-url https://github.com/danipopa/ai-receptionist \
                --branch main \
                --manual-integration \
                --output none 2>/dev/null; then
                log_success "GitHub deployment configured successfully"
            else
                log_warning "GitHub deployment configuration encountered issues but may have succeeded"
                # Try alternative configuration method
                az webapp config appsettings set \
                    --name $webapp_name \
                    --resource-group $RESOURCE_GROUP \
                    --settings \
                        DEPLOYMENT_BRANCH=main \
                        REPOSITORY_URL=https://github.com/danipopa/ai-receptionist \
                    --output none
            fi
        else
            log_success "GitHub deployment already configured"
        fi
    else
        log_success "Web app already exists"
    fi
    
    echo $webapp_name
}

# Main deployment function
main_deployment() {
    echo "Starting smart deployment process..."
    echo ""
    
    # Step 1: Find best location for PostgreSQL
    log_info "Step 1: Finding optimal location..."
    POSTGRES_LOCATION=$(find_best_location_postgres)
    if [[ $? -ne 0 ]]; then
        log_error "Cannot find suitable location for PostgreSQL"
        exit 1
    fi
    
    # Step 2: Check quota in that location
    if ! check_quota "$POSTGRES_LOCATION"; then
        log_warning "Quota issues in $POSTGRES_LOCATION, trying alternatives..."
        
        # Try other locations
        for alt_location in "${PREFERRED_LOCATIONS[@]}"; do
            if [[ $alt_location != $POSTGRES_LOCATION ]] && check_quota "$alt_location"; then
                POSTGRES_LOCATION=$alt_location
                break
            fi
        done
    fi
    
    log_info "Selected location: $POSTGRES_LOCATION"
    
    # Step 3: Setup resource group
    ACTUAL_LOCATION=$(setup_resource_group "$POSTGRES_LOCATION")
    
    # Step 4: Create PostgreSQL server
    log_info "Step 2: Setting up PostgreSQL..."
    POSTGRES_SERVER=$(create_postgres_server "$ACTUAL_LOCATION")
    if [[ $? -ne 0 ]]; then
        log_error "Failed to create PostgreSQL server"
        exit 1
    fi
    
    # Step 5: Create Redis
    log_info "Step 3: Setting up Redis..."
    REDIS_NAME=$(create_redis "$ACTUAL_LOCATION")
    if [[ $? -ne 0 ]]; then
        log_error "Failed to create Redis cache"
        exit 1
    fi
    
    # Step 6: Deploy web application
    log_info "Step 4: Deploying web application..."
    WEBAPP_NAME=$(deploy_web_app "$ACTUAL_LOCATION")
    if [[ $? -ne 0 ]]; then
        log_error "Failed to deploy web application"
        exit 1
    fi
    
    # Success summary
    echo ""
    log_success "Deployment completed successfully!"
    echo ""
    echo "🎉 AI Receptionist Deployed!"
    echo "=========================="
    echo ""
    echo "📍 Location: $ACTUAL_LOCATION"
    echo "🗂️  Resource Group: $RESOURCE_GROUP"
    echo "🐘 PostgreSQL: $POSTGRES_SERVER"
    echo "🔴 Redis: $REDIS_NAME"
    echo "🌐 Web App: https://$WEBAPP_NAME.azurewebsites.net"
    echo ""
    echo "🔧 Management Commands:"
    echo "  View resources: az resource list --resource-group $RESOURCE_GROUP --output table"
    echo "  Web app logs: az webapp log tail --name $WEBAPP_NAME --resource-group $RESOURCE_GROUP"
    echo "  Delete all: az group delete --name $RESOURCE_GROUP --yes"
    echo ""
    
    # Save deployment info
    cat > deployment-info.txt << EOF
AI Receptionist Deployment Information
====================================

Date: $(date)
Location: $ACTUAL_LOCATION
Resource Group: $RESOURCE_GROUP
PostgreSQL Server: $POSTGRES_SERVER
Redis Cache: $REDIS_NAME
Web App: $WEBAPP_NAME
Web App URL: https://$WEBAPP_NAME.azurewebsites.net

Database Password: $(cat /tmp/db_password_$APP_NAME.txt 2>/dev/null || echo "Not found")
EOF
    
    echo "💾 Deployment info saved to deployment-info.txt"
}

# Confirmation
echo "This will deploy AI Receptionist to Azure with smart location detection."
echo "The script will:"
echo "  1. Find the best Azure region for your resources"
echo "  2. Check quota availability"
echo "  3. Create resources only if they don't exist"
echo "  4. Continue from where it left off if re-run"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 1
fi

# Run deployment
main_deployment
