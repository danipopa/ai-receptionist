#!/bin/bash

# Simple Azure Deployment for AI Receptionist
# Quick deployment using Docker Compose on Azure Container Instances

set -e

# Configuration
RESOURCE_GROUP="ai-receptionist-simple"
LOCATION="eastus2"
STORAGE_ACCOUNT="aireceptionist$(date +%s | tail -c 6)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "🚀 Simple Azure Deployment for AI Receptionist"
echo "=============================================="
echo ""
echo "This will create a simple deployment using Azure Container Instances"
echo "Estimated cost: ~$100-200/month"
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

# Create storage account for persistent data
log_info "Creating storage account..."
az storage account create \
    --name $STORAGE_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Standard_LRS

# Get storage account key
STORAGE_KEY=$(az storage account keys list \
    --resource-group $RESOURCE_GROUP \
    --account-name $STORAGE_ACCOUNT \
    --query '[0].value' \
    --output tsv)

# Create file shares for persistent volumes
log_info "Creating file shares..."
az storage share create --name ai-data --account-name $STORAGE_ACCOUNT --account-key $STORAGE_KEY
az storage share create --name postgres-data --account-name $STORAGE_ACCOUNT --account-key $STORAGE_KEY
az storage share create --name redis-data --account-name $STORAGE_ACCOUNT --account-key $STORAGE_KEY

# Create container group with Docker Compose
log_info "Creating container deployment..."

# Generate secure passwords
DB_PASSWORD=$(openssl rand -base64 32)
REDIS_PASSWORD=$(openssl rand -base64 32)
SECRET_KEY=$(openssl rand -base64 32)

# Create the container group
az container create \
    --resource-group $RESOURCE_GROUP \
    --name ai-receptionist-app \
    --image postgres:14 \
    --environment-variables \
        POSTGRES_DB=ai_receptionist \
        POSTGRES_USER=receptionist \
        POSTGRES_PASSWORD=$DB_PASSWORD \
    --azure-file-volume-account-name $STORAGE_ACCOUNT \
    --azure-file-volume-account-key $STORAGE_KEY \
    --azure-file-volume-share-name postgres-data \
    --azure-file-volume-mount-path /var/lib/postgresql/data \
    --ports 5432 \
    --cpu 1 \
    --memory 2

# Create Redis container
az container create \
    --resource-group $RESOURCE_GROUP \
    --name ai-receptionist-redis \
    --image redis:7-alpine \
    --command-line "redis-server --requirepass $REDIS_PASSWORD" \
    --azure-file-volume-account-name $STORAGE_ACCOUNT \
    --azure-file-volume-account-key $STORAGE_KEY \
    --azure-file-volume-share-name redis-data \
    --azure-file-volume-mount-path /data \
    --ports 6379 \
    --cpu 0.5 \
    --memory 1

# Wait for database to be ready
log_info "Waiting for database to be ready..."
sleep 30

# Get container IPs
DB_IP=$(az container show --resource-group $RESOURCE_GROUP --name ai-receptionist-app --query ipAddress.ip --output tsv)
REDIS_IP=$(az container show --resource-group $RESOURCE_GROUP --name ai-receptionist-redis --query ipAddress.ip --output tsv)

# Create backend container
az container create \
    --resource-group $RESOURCE_GROUP \
    --name ai-receptionist-backend \
    --image python:3.11-slim \
    --command-line "/bin/bash -c \"
        pip install fastapi uvicorn psycopg2-binary redis sqlalchemy alembic && \
        git clone https://github.com/danipopa/ai-receptionist.git /app && \
        cd /app/backend && \
        export DATABASE_URL='postgresql://receptionist:$DB_PASSWORD@$DB_IP:5432/ai_receptionist' && \
        export REDIS_URL='redis://:$REDIS_PASSWORD@$REDIS_IP:6379' && \
        export SECRET_KEY='$SECRET_KEY' && \
        uvicorn app.main:app --host 0.0.0.0 --port 8000
    \"" \
    --ports 8000 \
    --cpu 2 \
    --memory 4

# Create frontend container  
az container create \
    --resource-group $RESOURCE_GROUP \
    --name ai-receptionist-frontend \
    --image nginx:alpine \
    --command-line "/bin/sh -c \"
        apk add --no-cache git nodejs npm && \
        git clone https://github.com/danipopa/ai-receptionist.git /tmp/app && \
        cd /tmp/app/frontend && \
        npm install && \
        npm run build && \
        cp -r dist/* /usr/share/nginx/html/ && \
        nginx -g 'daemon off;'
    \"" \
    --ports 80 \
    --cpu 1 \
    --memory 2

log_success "Deployment completed!"

# Get frontend IP
FRONTEND_IP=$(az container show --resource-group $RESOURCE_GROUP --name ai-receptionist-frontend --query ipAddress.ip --output tsv)
BACKEND_IP=$(az container show --resource-group $RESOURCE_GROUP --name ai-receptionist-backend --query ipAddress.ip --output tsv)

echo ""
echo "🎉 AI Receptionist deployed successfully!"
echo "========================================"
echo ""
echo "📊 Access URLs:"
echo "  Frontend: http://$FRONTEND_IP"
echo "  Backend API: http://$BACKEND_IP:8000"
echo "  API Docs: http://$BACKEND_IP:8000/docs"
echo ""
echo "🔐 Database Credentials:"
echo "  Host: $DB_IP"
echo "  User: receptionist"
echo "  Password: $DB_PASSWORD"
echo "  Database: ai_receptionist"
echo ""
echo "📊 Management:"
echo "  View containers: az container list --resource-group $RESOURCE_GROUP --output table"
echo "  View logs: az container logs --resource-group $RESOURCE_GROUP --name ai-receptionist-backend"
echo "  Delete deployment: az group delete --name $RESOURCE_GROUP --yes"
echo ""
echo "💰 Estimated monthly cost: ~$150-250"
echo ""
echo "⚠️  Note: This is a basic deployment for testing."
echo "   For production, use the full deployment script with load balancing and SSL."
