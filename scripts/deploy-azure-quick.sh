#!/bin/bash

# Quick Azure Deployment - Web App Only
# Deploys just the frontend dashboard quickly

set -e

# Configuration
RESOURCE_GROUP="ai-receptionist-quick"
LOCATION="centralus"
APP_NAME="ai-receptionist-$(date +%s | tail -c 6)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

echo "🚀 Quick Azure Web App Deployment"
echo "================================="
echo ""
echo "This will deploy just the AI Receptionist dashboard"
echo "Cost: ~$13/month (Free tier available)"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 1
fi

# Create resource group
log_info "Creating resource group..."
if ! az group exists --name $RESOURCE_GROUP --output tsv 2>/dev/null | grep -q "true"; then
    az group create --name $RESOURCE_GROUP --location $LOCATION --output table
else
    log_success "Resource group already exists"
fi

# Create App Service plan
PLAN_NAME="ai-receptionist-plan"
log_info "Creating App Service plan..."
if ! az appservice plan show --name $PLAN_NAME --resource-group $RESOURCE_GROUP >/dev/null 2>&1; then
    az appservice plan create \
        --name $PLAN_NAME \
        --resource-group $RESOURCE_GROUP \
        --location $LOCATION \
        --sku F1 \
        --is-linux \
        --output table
else
    log_success "App Service plan already exists"
fi

# Create web app
WEBAPP_NAME="ai-receptionist-$APP_NAME"
log_info "Creating web app..."
if ! az webapp show --name $WEBAPP_NAME --resource-group $RESOURCE_GROUP >/dev/null 2>&1; then
    az webapp create \
        --name $WEBAPP_NAME \
        --resource-group $RESOURCE_GROUP \
        --plan $PLAN_NAME \
        --runtime "NODE:20-lts" \
        --output table
    
    # Configure app settings for Node.js
    az webapp config appsettings set \
        --name $WEBAPP_NAME \
        --resource-group $RESOURCE_GROUP \
        --settings \
            WEBSITE_NODE_DEFAULT_VERSION=20 \
            SCM_DO_BUILD_DURING_DEPLOYMENT=true
    
    # Set startup command
    az webapp config set \
        --name $WEBAPP_NAME \
        --resource-group $RESOURCE_GROUP \
        --startup-file "cd frontend && npm install && npm run build && npx serve -s dist -p 8080"
    
    # Configure GitHub deployment
    log_info "Configuring GitHub deployment..."
    
    # First, check if deployment source is already configured
    existing_source=$(az webapp deployment source show \
        --name $WEBAPP_NAME \
        --resource-group $RESOURCE_GROUP \
        --query "repoUrl" \
        --output tsv 2>/dev/null || echo "")
    
    if [[ -z "$existing_source" ]]; then
        # Configure GitHub deployment with error handling
        if az webapp deployment source config \
            --name $WEBAPP_NAME \
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
                --name $WEBAPP_NAME \
                --resource-group $RESOURCE_GROUP \
                --settings \
                    DEPLOYMENT_BRANCH=main \
                    REPOSITORY_URL=https://github.com/danipopa/ai-receptionist \
                --output none
        fi
    else
        log_success "GitHub deployment already configured"
    fi
        
    log_success "Web app created and configured"
else
    log_success "Web app already exists"
fi

echo ""
log_success "Deployment completed!"
echo ""
echo "🎉 AI Receptionist Dashboard Deployed!"
echo "====================================="
echo ""
echo "📍 Location: $LOCATION"
echo "🗂️  Resource Group: $RESOURCE_GROUP"
echo "🌐 Web App: https://$WEBAPP_NAME.azurewebsites.net"
echo ""
echo "🔧 Management:"
echo "  View logs: az webapp log tail --name $WEBAPP_NAME --resource-group $RESOURCE_GROUP"
echo "  Restart: az webapp restart --name $WEBAPP_NAME --resource-group $RESOURCE_GROUP"
echo "  Delete: az group delete --name $RESOURCE_GROUP --yes"
echo ""
echo "💰 Cost: FREE (F1 tier) or ~$13/month (B1 tier)"
echo ""
echo "⚠️  Note: This is the frontend dashboard only."
echo "   For full AI functionality, backend services are needed."
echo ""
echo "🔄 The deployment build may take 5-10 minutes."
echo "   Monitor progress: az webapp log tail --name $WEBAPP_NAME --resource-group $RESOURCE_GROUP"

# Save deployment info
cat > quick-deployment.txt << EOF
AI Receptionist Quick Deployment
===============================

Date: $(date)
Location: $LOCATION
Resource Group: $RESOURCE_GROUP
Web App Name: $WEBAPP_NAME
Web App URL: https://$WEBAPP_NAME.azurewebsites.net

To monitor deployment:
az webapp log tail --name $WEBAPP_NAME --resource-group $RESOURCE_GROUP

To delete:
az group delete --name $RESOURCE_GROUP --yes
EOF

echo ""
echo "💾 Deployment info saved to quick-deployment.txt"
