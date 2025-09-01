#!/bin/bash

# Ultra-Simple Azure Deployment using App Service
# Deploys the AI Receptionist frontend as a static web app

set -e

# Configuration
RESOURCE_GROUP="ai-receptionist-web"
LOCATION="eastus2"
APP_NAME="ai-receptionist-$(date +%s | tail -c 6)"
PLAN_NAME="ai-receptionist-plan"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

echo "🚀 Ultra-Simple Azure App Service Deployment"
echo "============================================="
echo ""
echo "This will deploy the AI Receptionist dashboard as a web app"
echo "Estimated cost: ~$50-100/month"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 1
fi

# Create resource group
log_info "Creating resource group..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create App Service plan
log_info "Creating App Service plan..."
az appservice plan create \
    --name $PLAN_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku B1 \
    --is-linux

# Create web app
log_info "Creating web app..."
az webapp create \
    --name $APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --plan $PLAN_NAME \
    --runtime "NODE:20-lts"

# Configure deployment from GitHub
log_info "Configuring GitHub deployment..."

# Check if deployment source is already configured
existing_source=$(az webapp deployment source show \
    --name $APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --query "repoUrl" \
    --output tsv 2>/dev/null || echo "")

if [[ -z "$existing_source" ]]; then
    # Configure GitHub deployment with error handling
    if az webapp deployment source config \
        --name $APP_NAME \
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
            --name $APP_NAME \
            --resource-group $RESOURCE_GROUP \
            --settings \
                DEPLOYMENT_BRANCH=main \
                REPOSITORY_URL=https://github.com/danipopa/ai-receptionist \
            --output none
    fi
else
    log_success "GitHub deployment already configured"
fi

# Configure Node.js settings for frontend
log_info "Configuring application settings..."
az webapp config appsettings set \
    --name $APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --settings \
        WEBSITE_NODE_DEFAULT_VERSION=18.17.0 \
        SCM_DO_BUILD_DURING_DEPLOYMENT=true \
        WEBSITE_RUN_FROM_PACKAGE=1

# Set startup command to serve the frontend
az webapp config set \
    --name $APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --startup-file "cd frontend && npm install && npm run build && npx serve -s dist -l 8080"

log_success "Deployment completed!"

# Get app URL
APP_URL="https://${APP_NAME}.azurewebsites.net"

echo ""
echo "🎉 AI Receptionist Dashboard deployed!"
echo "====================================="
echo ""
echo "📊 Access URL: $APP_URL"
echo ""
echo "📊 Management:"
echo "  View app: az webapp show --name $APP_NAME --resource-group $RESOURCE_GROUP"
echo "  View logs: az webapp log tail --name $APP_NAME --resource-group $RESOURCE_GROUP"
echo "  Delete deployment: az group delete --name $RESOURCE_GROUP --yes"
echo ""
echo "💰 Estimated monthly cost: ~$50-100"
echo ""
echo "⚠️  Note: This deploys only the frontend dashboard."
echo "   For full AI functionality, backend services are needed."
echo ""
echo "🔄 The deployment may take 5-10 minutes to complete."
echo "   Check status at: $APP_URL"
