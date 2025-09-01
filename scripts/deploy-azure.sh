#!/bin/bash

# Azure AI Receptionist Deployment Script
# Quick deployment using Azure Container Instances

set -e

echo "🚀 Deploying AI Receptionist to Azure"
echo "====================================="

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

# Configuration
RESOURCE_GROUP="ai-receptionist-prod-rg"
LOCATION="eastus2"
ACR_NAME="aireceptionistacr$(date +%s)"
STORAGE_ACCOUNT="aireceptionist$(date +%s)"
DB_SERVER="ai-receptionist-db-$(date +%s)"
DB_NAME="ai_receptionist"
DB_USER="receptionist_admin"
DB_PASSWORD=$(openssl rand -base64 32)

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI not installed. Please install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    if ! az account show &> /dev/null; then
        log_error "Not logged into Azure. Please run: az login"
        exit 1
    fi
    
    log_success "Prerequisites check passed!"
}

# Create resource group
create_resource_group() {
    log_info "Creating resource group: $RESOURCE_GROUP"
    
    az group create \
        --name $RESOURCE_GROUP \
        --location $LOCATION \
        --output table
    
    log_success "Resource group created!"
}

# Create container registry
create_container_registry() {
    log_info "Creating Azure Container Registry: $ACR_NAME"
    
    az acr create \
        --resource-group $RESOURCE_GROUP \
        --name $ACR_NAME \
        --sku Basic \
        --admin-enabled true \
        --output table
    
    log_success "Container registry created!"
}

# Build and push images
build_and_push_images() {
    log_info "Building and pushing container images..."
    
    # Get ACR login server
    ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)
    
    # Login to ACR
    az acr login --name $ACR_NAME
    
    # Build and push backend
    log_info "Building backend image..."
    docker build -t $ACR_LOGIN_SERVER/ai-receptionist-backend:latest ./backend
    docker push $ACR_LOGIN_SERVER/ai-receptionist-backend:latest
    
    # Build and push frontend
    log_info "Building frontend image..."
    docker build -t $ACR_LOGIN_SERVER/ai-receptionist-frontend:latest ./frontend
    docker push $ACR_LOGIN_SERVER/ai-receptionist-frontend:latest
    
    # Build and push Rasa
    log_info "Building Rasa image..."
    docker build -t $ACR_LOGIN_SERVER/ai-receptionist-rasa:latest ./ai-engine/rasa
    docker push $ACR_LOGIN_SERVER/ai-receptionist-rasa:latest
    
    log_success "All images built and pushed!"
}

# Create PostgreSQL database
create_database() {
    log_info "Creating PostgreSQL Flexible Server..."
    
    az postgres flexible-server create \
        --resource-group $RESOURCE_GROUP \
        --name $DB_SERVER \
        --location $LOCATION \
        --admin-user $DB_USER \
        --admin-password $DB_PASSWORD \
        --sku-name Standard_B2s \
        --tier Burstable \
        --version 14 \
        --storage-size 128 \
        --public-access 0.0.0.0 \
        --output table
    
    # Create database
    az postgres flexible-server db create \
        --resource-group $RESOURCE_GROUP \
        --server-name $DB_SERVER \
        --database-name $DB_NAME \
        --output table
    
    log_success "Database created!"
}

# Create Redis cache
create_redis() {
    log_info "Creating Redis cache..."
    
    az redis create \
        --location $LOCATION \
        --name ai-receptionist-redis \
        --resource-group $RESOURCE_GROUP \
        --sku Basic \
        --vm-size c0 \
        --output table
    
    log_success "Redis cache created!"
}

# Create storage account
create_storage() {
    log_info "Creating storage account..."
    
    az storage account create \
        --name $STORAGE_ACCOUNT \
        --resource-group $RESOURCE_GROUP \
        --location $LOCATION \
        --sku Standard_LRS \
        --output table
    
    log_success "Storage account created!"
}

# Deploy containers
deploy_containers() {
    log_info "Deploying container instances..."
    
    # Get ACR credentials
    ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)
    ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username --output tsv)
    ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query passwords[0].value --output tsv)
    
    # Get database connection string
    DB_HOST="${DB_SERVER}.postgres.database.azure.com"
    DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:5432/${DB_NAME}"
    
    # Get Redis connection string
    REDIS_HOST=$(az redis show --name ai-receptionist-redis --resource-group $RESOURCE_GROUP --query hostName --output tsv)
    REDIS_KEY=$(az redis list-keys --name ai-receptionist-redis --resource-group $RESOURCE_GROUP --query primaryKey --output tsv)
    REDIS_URL="redis://:${REDIS_KEY}@${REDIS_HOST}:6380"
    
    # Deploy backend
    log_info "Deploying backend container..."
    az container create \
        --resource-group $RESOURCE_GROUP \
        --name ai-receptionist-backend \
        --image $ACR_LOGIN_SERVER/ai-receptionist-backend:latest \
        --registry-login-server $ACR_LOGIN_SERVER \
        --registry-username $ACR_USERNAME \
        --registry-password $ACR_PASSWORD \
        --dns-name-label ai-receptionist-api-$(date +%s) \
        --ports 8000 \
        --environment-variables \
            DATABASE_URL="$DATABASE_URL" \
            REDIS_URL="$REDIS_URL" \
            OLLAMA_API_URL="http://localhost:11434" \
            RASA_API_URL="http://ai-receptionist-rasa.${LOCATION}.azurecontainer.io:5005" \
        --cpu 2 \
        --memory 4 \
        --output table
    
    # Deploy Rasa
    log_info "Deploying Rasa container..."
    az container create \
        --resource-group $RESOURCE_GROUP \
        --name ai-receptionist-rasa \
        --image $ACR_LOGIN_SERVER/ai-receptionist-rasa:latest \
        --registry-login-server $ACR_LOGIN_SERVER \
        --registry-username $ACR_USERNAME \
        --registry-password $ACR_PASSWORD \
        --dns-name-label ai-receptionist-rasa-$(date +%s) \
        --ports 5005 \
        --cpu 1 \
        --memory 2 \
        --output table
    
    # Deploy Ollama (for AI inference)
    log_info "Deploying Ollama container..."
    az container create \
        --resource-group $RESOURCE_GROUP \
        --name ai-receptionist-ollama \
        --image ollama/ollama:latest \
        --dns-name-label ai-receptionist-ollama-$(date +%s) \
        --ports 11434 \
        --cpu 2 \
        --memory 8 \
        --output table
    
    # Get backend URL
    BACKEND_URL=$(az container show --resource-group $RESOURCE_GROUP --name ai-receptionist-backend --query ipAddress.fqdn --output tsv)
    
    # Deploy frontend
    log_info "Deploying frontend container..."
    az container create \
        --resource-group $RESOURCE_GROUP \
        --name ai-receptionist-frontend \
        --image $ACR_LOGIN_SERVER/ai-receptionist-frontend:latest \
        --registry-login-server $ACR_LOGIN_SERVER \
        --registry-username $ACR_USERNAME \
        --registry-password $ACR_PASSWORD \
        --dns-name-label ai-receptionist-app-$(date +%s) \
        --ports 80 \
        --environment-variables \
            REACT_APP_API_URL="http://${BACKEND_URL}:8000" \
        --cpu 1 \
        --memory 1 \
        --output table
    
    log_success "All containers deployed!"
}

# Setup monitoring
setup_monitoring() {
    log_info "Setting up Application Insights..."
    
    az extension add --name application-insights
    
    az monitor app-insights component create \
        --app ai-receptionist-insights \
        --location $LOCATION \
        --resource-group $RESOURCE_GROUP \
        --output table
    
    log_success "Monitoring configured!"
}

# Display deployment info
show_deployment_info() {
    echo ""
    echo "🎉 Deployment Complete!"
    echo "======================"
    echo ""
    
    # Get URLs
    FRONTEND_URL=$(az container show --resource-group $RESOURCE_GROUP --name ai-receptionist-frontend --query ipAddress.fqdn --output tsv)
    BACKEND_URL=$(az container show --resource-group $RESOURCE_GROUP --name ai-receptionist-backend --query ipAddress.fqdn --output tsv)
    
    echo "📊 Access URLs:"
    echo "  Frontend: http://${FRONTEND_URL}"
    echo "  Backend API: http://${BACKEND_URL}:8000"
    echo "  API Docs: http://${BACKEND_URL}:8000/docs"
    echo ""
    echo "🔧 Azure Resources:"
    echo "  Resource Group: $RESOURCE_GROUP"
    echo "  Database: $DB_SERVER"
    echo "  Container Registry: $ACR_NAME"
    echo ""
    echo "🔐 Database Credentials:"
    echo "  Username: $DB_USER"
    echo "  Password: $DB_PASSWORD"
    echo "  Connection: postgresql://${DB_USER}:${DB_PASSWORD}@${DB_SERVER}.postgres.database.azure.com:5432/${DB_NAME}"
    echo ""
    echo "💡 Next Steps:"
    echo "  1. Configure your SIP provider details"
    echo "  2. Add your first business via the dashboard"
    echo "  3. Test the system with a SIP phone"
    echo "  4. Configure SSL/TLS for production"
    echo ""
    echo "🛠️ Management Commands:"
    echo "  Monitor: az container logs --resource-group $RESOURCE_GROUP --name ai-receptionist-backend --follow"
    echo "  Scale: az container create --resource-group $RESOURCE_GROUP --cpu 4 --memory 8"
    echo "  Delete: az group delete --name $RESOURCE_GROUP --yes"
}

# Main deployment flow
main() {
    check_prerequisites
    create_resource_group
    create_container_registry
    create_database
    create_redis
    create_storage
    build_and_push_images
    deploy_containers
    setup_monitoring
    show_deployment_info
}

# Handle interruption
trap 'log_error "Deployment interrupted"; exit 1' INT

# Confirmation
echo "This will deploy the AI Receptionist platform to Azure."
echo "Estimated cost: ~$300-500/month for basic deployment"
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 1
fi

# Run deployment
main
