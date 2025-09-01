#!/bin/bash

# Immediate Azure Static Web App Deployment
# Deploys just the frontend using Azure Static Web Apps (free tier)

set -e

# Configuration  
RESOURCE_GROUP="aireceptionist$(date +%s | tail -c 4)"
LOCATION="eastus2"
SWA_NAME="ai-receptionist-$(date +%s | tail -c 6)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

echo "🚀 Azure Static Web App Deployment"
echo "=================================="
echo ""
echo "This will deploy the AI Receptionist dashboard using Azure Static Web Apps"
echo "Cost: FREE (within limits)"
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

# Create static web app
log_info "Creating Static Web App..."
SWA_JSON=$(az staticwebapp create \
    --name $SWA_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --source https://github.com/danipopa/ai-receptionist \
    --branch main \
    --app-location "/frontend" \
    --output-location "dist")

# Get the URL
SWA_URL=$(echo $SWA_JSON | jq -r '.defaultHostname')

log_success "Deployment completed!"

echo ""
echo "🎉 AI Receptionist Dashboard deployed!"
echo "====================================="
echo ""
echo "📊 Access URL: https://$SWA_URL"
echo ""
echo "📊 Management:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Static Web App: $SWA_NAME"
echo "  Delete: az group delete --name $RESOURCE_GROUP --yes"
echo ""
echo "💰 Cost: FREE (Azure Static Web Apps free tier)"
echo ""
echo "⚠️  Note: This deploys only the frontend dashboard."
echo "   Backend services need separate deployment for full functionality."
echo ""
echo "🔄 The build may take 5-10 minutes to complete."
echo "   Check deployment status in Azure portal."
