#!/bin/bash

# Smart Azure Deployment for AI Receptionist
# Checks existing resources and continues from where it left off

set -e

# Configuration
RESOURCE_GROUP="ai-receptionist-rg"
LOCATION="westus2"
ACR_NAME="aireceptionistacr"
APP_SERVICE_PLAN="ai-receptionist-plan"
WEB_APP_NAME="ai-receptionist-web"
DB_SERVER="ai-receptionist-db"
REDIS_NAME="ai-receptionist-redis"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; }

# Check if resource exists
resource_exists() {
    local resource_type=$1
    local resource_name=$2
    local resource_group=${3:-$RESOURCE_GROUP}
    
    case $resource_type in
        "group")
            az group show --name $resource_name &>/dev/null
            ;;
        "acr")
            az acr show --name $resource_name &>/dev/null
            ;;
        "appservice-plan")
            az appservice plan show --name $resource_name --resource-group $resource_group &>/dev/null
            ;;
        "webapp")
            az webapp show --name $resource_name --resource-group $resource_group &>/dev/null
            ;;
        "postgres")
            az postgres flexible-server show --name $resource_name --resource-group $resource_group &>/dev/null
            ;;
        "redis")
            az redis show --name $resource_name --resource-group $resource_group &>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Wait for resource to be ready
wait_for_resource() {
    local resource_type=$1
    local resource_name=$2
    local max_attempts=${3:-30}
    local attempt=1
    
    log_info "Waiting for $resource_type '$resource_name' to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if resource_exists "$resource_type" "$resource_name"; then
            local status=""
            case $resource_type in
                "postgres")
                    status=$(az postgres flexible-server show --name $resource_name --resource-group $RESOURCE_GROUP --query state --output tsv 2>/dev/null || echo "NotFound")
                    if [[ "$status" == "Ready" ]]; then
                        log_success "$resource_type '$resource_name' is ready!"
                        return 0
                    fi
                    ;;
                "redis")
                    status=$(az redis show --name $resource_name --resource-group $RESOURCE_GROUP --query provisioningState --output tsv 2>/dev/null || echo "NotFound")
                    if [[ "$status" == "Succeeded" ]]; then
                        log_success "$resource_type '$resource_name' is ready!"
                        return 0
                    fi
                    ;;
                "webapp")
                    status=$(az webapp show --name $resource_name --resource-group $RESOURCE_GROUP --query state --output tsv 2>/dev/null || echo "NotFound")
                    if [[ "$status" == "Running" ]]; then
                        log_success "$resource_type '$resource_name' is ready!"
                        return 0
                    fi
                    ;;
                *)
                    log_success "$resource_type '$resource_name' exists!"
                    return 0
                    ;;
            esac
            log_info "Status: $status (attempt $attempt/$max_attempts)"
        fi
        
        sleep 10
        ((attempt++))
    done
    
    log_error "$resource_type '$resource_name' not ready after $max_attempts attempts"
    return 1
}

# Create or check resource group
setup_resource_group() {
    if resource_exists "group" "$RESOURCE_GROUP"; then
        log_skip "Resource group '$RESOURCE_GROUP' already exists"
    else
        log_info "Creating resource group '$RESOURCE_GROUP'..."
        az group create --name $RESOURCE_GROUP --location $LOCATION --output table
        log_success "Resource group created!"
    fi
}

# Create or check Azure Container Registry
setup_acr() {
    if resource_exists "acr" "$ACR_NAME"; then
        log_skip "ACR '$ACR_NAME' already exists"
    else
        log_info "Creating Azure Container Registry '$ACR_NAME'..."
        az acr create \
            --resource-group $RESOURCE_GROUP \
            --name $ACR_NAME \
            --sku Basic \
            --admin-enabled true \
            --output table
        
        wait_for_resource "acr" "$ACR_NAME"
        log_success "ACR created!"
    fi
    
    # Get ACR credentials
    ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)
    ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username --output tsv)
    ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query passwords[0].value --output tsv)
    
    log_info "ACR Login Server: $ACR_LOGIN_SERVER"
}

# Create or check App Service Plan
setup_app_service_plan() {
    if resource_exists "appservice-plan" "$APP_SERVICE_PLAN"; then
        log_skip "App Service Plan '$APP_SERVICE_PLAN' already exists"
    else
        log_info "Creating App Service Plan '$APP_SERVICE_PLAN'..."
        az appservice plan create \
            --name $APP_SERVICE_PLAN \
            --resource-group $RESOURCE_GROUP \
            --location $LOCATION \
            --sku B1 \
            --is-linux \
            --output table
        
        wait_for_resource "appservice-plan" "$APP_SERVICE_PLAN"
        log_success "App Service Plan created!"
    fi
}

# Create or check PostgreSQL
setup_database() {
    if resource_exists "postgres" "$DB_SERVER"; then
        log_skip "PostgreSQL server '$DB_SERVER' already exists"
    else
        log_info "Creating PostgreSQL Flexible Server '$DB_SERVER'..."
        
        # Generate password if not exists
        if [ ! -f ".db_password" ]; then
            openssl rand -base64 32 > .db_password
            chmod 600 .db_password
        fi
        DB_PASSWORD=$(cat .db_password)
        
        az postgres flexible-server create \
            --resource-group $RESOURCE_GROUP \
            --name $DB_SERVER \
            --location $LOCATION \
            --admin-user receptionist_admin \
            --admin-password $DB_PASSWORD \
            --sku-name Standard_B2s \
            --tier Burstable \
            --version 14 \
            --storage-size 128 \
            --public-access 0.0.0.0 \
            --output table
        
        wait_for_resource "postgres" "$DB_SERVER" 60
        
        # Create database
        log_info "Creating database 'ai_receptionist'..."
        az postgres flexible-server db create \
            --resource-group $RESOURCE_GROUP \
            --server-name $DB_SERVER \
            --database-name ai_receptionist \
            --output table
        
        log_success "Database created!"
    fi
    
    # Get database credentials
    if [ -f ".db_password" ]; then
        DB_PASSWORD=$(cat .db_password)
        DB_HOST="${DB_SERVER}.postgres.database.azure.com"
        DATABASE_URL="postgresql://receptionist_admin:${DB_PASSWORD}@${DB_HOST}:5432/ai_receptionist"
        log_info "Database URL configured"
    else
        log_error "Database password file not found!"
        exit 1
    fi
}

# Create or check Redis
setup_redis() {
    if resource_exists "redis" "$REDIS_NAME"; then
        log_skip "Redis cache '$REDIS_NAME' already exists"
    else
        log_info "Creating Redis cache '$REDIS_NAME'..."
        az redis create \
            --location $LOCATION \
            --name $REDIS_NAME \
            --resource-group $RESOURCE_GROUP \
            --sku Basic \
            --vm-size c0 \
            --output table
        
        wait_for_resource "redis" "$REDIS_NAME" 60
        log_success "Redis created!"
    fi
    
    # Get Redis connection
    REDIS_HOST=$(az redis show --name $REDIS_NAME --resource-group $RESOURCE_GROUP --query hostName --output tsv)
    REDIS_KEY=$(az redis list-keys --name $REDIS_NAME --resource-group $RESOURCE_GROUP --query primaryKey --output tsv)
    REDIS_URL="redis://:${REDIS_KEY}@${REDIS_HOST}:6380"
    log_info "Redis URL configured"
}

# Build and push images
build_and_push_images() {
    log_info "Checking if images need to be built..."
    
    # Login to ACR
    az acr login --name $ACR_NAME
    
    # Check if images exist
    backend_exists=$(az acr repository show --name $ACR_NAME --repository ai-receptionist-backend 2>/dev/null || echo "false")
    frontend_exists=$(az acr repository show --name $ACR_NAME --repository ai-receptionist-frontend 2>/dev/null || echo "false")
    
    if [[ "$backend_exists" == "false" ]]; then
        log_info "Building and pushing backend image..."
        docker build -t $ACR_LOGIN_SERVER/ai-receptionist-backend:latest ./backend
        docker push $ACR_LOGIN_SERVER/ai-receptionist-backend:latest
        log_success "Backend image pushed!"
    else
        log_skip "Backend image already exists"
    fi
    
    if [[ "$frontend_exists" == "false" ]]; then
        log_info "Building and pushing frontend image..."
        docker build -t $ACR_LOGIN_SERVER/ai-receptionist-frontend:latest ./frontend
        docker push $ACR_LOGIN_SERVER/ai-receptionist-frontend:latest
        log_success "Frontend image pushed!"
    else
        log_skip "Frontend image already exists"
    fi
}

# Deploy web app
deploy_webapp() {
    if resource_exists "webapp" "$WEB_APP_NAME"; then
        log_skip "Web app '$WEB_APP_NAME' already exists"
        log_info "Updating existing web app configuration..."
    else
        log_info "Creating web app '$WEB_APP_NAME'..."
        az webapp create \
            --resource-group $RESOURCE_GROUP \
            --plan $APP_SERVICE_PLAN \
            --name $WEB_APP_NAME \
            --deployment-container-image-name $ACR_LOGIN_SERVER/ai-receptionist-backend:latest \
            --output table
    fi
    
    # Configure container settings
    log_info "Configuring container settings..."
    az webapp config container set \
        --name $WEB_APP_NAME \
        --resource-group $RESOURCE_GROUP \
        --docker-custom-image-name $ACR_LOGIN_SERVER/ai-receptionist-backend:latest \
        --docker-registry-server-url https://$ACR_LOGIN_SERVER \
        --docker-registry-server-user $ACR_USERNAME \
        --docker-registry-server-password $ACR_PASSWORD
    
    # Set environment variables
    log_info "Setting environment variables..."
    az webapp config appsettings set \
        --resource-group $RESOURCE_GROUP \
        --name $WEB_APP_NAME \
        --settings \
            DATABASE_URL="$DATABASE_URL" \
            REDIS_URL="$REDIS_URL" \
            ENVIRONMENT="production" \
            PORT="8000" \
        --output table
    
    # Restart the app
    log_info "Restarting web app..."
    az webapp restart --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP
    
    wait_for_resource "webapp" "$WEB_APP_NAME"
    log_success "Web app deployed!"
}

# Display deployment info
show_deployment_info() {
    echo ""
    echo -e "${GREEN}🎉 AI Receptionist Deployed Successfully!${NC}"
    echo "=========================================="
    
    APP_URL=$(az webapp show --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP --query defaultHostName --output tsv)
    
    echo ""
    echo -e "${BLUE}📱 Application URLs:${NC}"
    echo "  Web App: https://$APP_URL"
    echo "  API Health: https://$APP_URL/health"
    echo "  API Docs: https://$APP_URL/docs"
    echo ""
    
    echo -e "${BLUE}🔧 Azure Resources:${NC}"
    echo "  Resource Group: $RESOURCE_GROUP"
    echo "  Container Registry: $ACR_NAME"
    echo "  Web App: $WEB_APP_NAME"
    echo "  Database: $DB_SERVER"
    echo "  Redis: $REDIS_NAME"
    echo ""
    
    echo -e "${BLUE}🎛️ Management Commands:${NC}"
    echo "  View logs: az webapp log tail --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP"
    echo "  Scale up: az webapp up --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP --sku S1"
    echo "  SSH access: az webapp ssh --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP"
    echo ""
    
    if [ -f ".db_password" ]; then
        echo -e "${BLUE}🔐 Database Access:${NC}"
        echo "  Host: $DB_HOST"
        echo "  Username: receptionist_admin"
        echo "  Password: $(cat .db_password)"
        echo "  Database: ai_receptionist"
        echo ""
    fi
    
    echo -e "${YELLOW}💰 Estimated Monthly Cost: $50-150${NC}"
    echo "   (Basic tier - suitable for development/testing)"
    echo ""
    echo -e "${GREEN}✅ Deployment Complete! Your AI Receptionist is ready.${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Smart Azure Deployment for AI Receptionist${NC}"
    echo "=============================================="
    echo ""
    echo "This script will check existing resources and continue deployment."
    echo "No resources will be deleted or recreated unnecessarily."
    echo ""
    read -p "Continue with deployment? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled."
        exit 0
    fi
    
    echo ""
    log_info "Starting smart deployment process..."
    
    # Execute deployment steps
    setup_resource_group
    setup_acr
    setup_app_service_plan
    setup_database
    setup_redis
    build_and_push_images
    deploy_webapp
    show_deployment_info
}

# Handle interruption
trap 'log_error "Deployment interrupted"; exit 1' INT

# Run main function
main
