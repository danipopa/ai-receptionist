#!/bin/bash

# Azure Kubernetes Service (AKS) Deployment for AI Receptionist
# Production-ready deployment with auto-scaling and monitoring

set -e

echo "🚀 Deploying AI Receptionist to Azure Kubernetes Service"
echo "========================================================"

# Configuration
RESOURCE_GROUP="ai-receptionist-prod-rg"
LOCATION="eastus"
AKS_CLUSTER="ai-receptionist-aks"
ACR_NAME="aireceptionistprodacr$(date +%s)"
NODE_COUNT=3
VM_SIZE="Standard_D4s_v3"

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI not installed."
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not installed."
        exit 1
    fi
    
    # Check Helm
    if ! command -v helm &> /dev/null; then
        log_error "Helm not installed."
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker not installed."
        exit 1
    fi
    
    log_success "Prerequisites check passed!"
}

# Create resource group
create_resource_group() {
    log_info "Creating resource group..."
    
    az group create \
        --name $RESOURCE_GROUP \
        --location $LOCATION
    
    log_success "Resource group created!"
}

# Create container registry
create_acr() {
    log_info "Creating Azure Container Registry..."
    
    az acr create \
        --resource-group $RESOURCE_GROUP \
        --name $ACR_NAME \
        --sku Premium \
        --admin-enabled true
    
    log_success "ACR created!"
}

# Create AKS cluster
create_aks() {
    log_info "Creating AKS cluster (this may take 10-15 minutes)..."
    
    az aks create \
        --resource-group $RESOURCE_GROUP \
        --name $AKS_CLUSTER \
        --node-count $NODE_COUNT \
        --node-vm-size $VM_SIZE \
        --enable-addons monitoring \
        --attach-acr $ACR_NAME \
        --enable-cluster-autoscaler \
        --min-count 1 \
        --max-count 10 \
        --generate-ssh-keys
    
    # Get credentials
    az aks get-credentials \
        --resource-group $RESOURCE_GROUP \
        --name $AKS_CLUSTER \
        --overwrite-existing
    
    log_success "AKS cluster created!"
}

# Create managed databases
create_managed_services() {
    log_info "Creating managed PostgreSQL..."
    
    DB_SERVER="ai-receptionist-db-prod-$(date +%s)"
    DB_PASSWORD=$(openssl rand -base64 32)
    
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
        --public-access 0.0.0.0
    
    # Create database
    az postgres flexible-server db create \
        --resource-group $RESOURCE_GROUP \
        --server-name $DB_SERVER \
        --database-name ai_receptionist
    
    log_info "Creating managed Redis..."
    
    az redis create \
        --location $LOCATION \
        --name ai-receptionist-redis-prod \
        --resource-group $RESOURCE_GROUP \
        --sku Premium \
        --vm-size P1
    
    log_success "Managed services created!"
}

# Build and push images
build_and_push() {
    log_info "Building and pushing images..."
    
    ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)
    az acr login --name $ACR_NAME
    
    # Build all images
    docker build -t $ACR_LOGIN_SERVER/ai-receptionist-backend:latest ./backend
    docker build -t $ACR_LOGIN_SERVER/ai-receptionist-frontend:latest ./frontend
    docker build -t $ACR_LOGIN_SERVER/ai-receptionist-rasa:latest ./ai-engine/rasa
    
    # Push images
    docker push $ACR_LOGIN_SERVER/ai-receptionist-backend:latest
    docker push $ACR_LOGIN_SERVER/ai-receptionist-frontend:latest
    docker push $ACR_LOGIN_SERVER/ai-receptionist-rasa:latest
    
    log_success "Images built and pushed!"
}

# Create Kubernetes manifests
create_k8s_manifests() {
    log_info "Creating Kubernetes manifests..."
    
    mkdir -p deployment/kubernetes/production
    
    # Get connection strings
    ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)
    DB_HOST=$(az postgres flexible-server show --resource-group $RESOURCE_GROUP --name $DB_SERVER --query fullyQualifiedDomainName --output tsv)
    REDIS_HOST=$(az redis show --name ai-receptionist-redis-prod --resource-group $RESOURCE_GROUP --query hostName --output tsv)
    
    cat > deployment/kubernetes/production/namespace.yaml << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ai-receptionist
EOF

    cat > deployment/kubernetes/production/secrets.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ai-receptionist-secrets
  namespace: ai-receptionist
type: Opaque
stringData:
  DATABASE_URL: "postgresql://receptionist_admin:${DB_PASSWORD}@${DB_HOST}:5432/ai_receptionist"
  REDIS_URL: "redis://${REDIS_HOST}:6380"
  SECRET_KEY: "$(openssl rand -base64 32)"
EOF

    cat > deployment/kubernetes/production/backend-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: ai-receptionist
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: ${ACR_LOGIN_SERVER}/ai-receptionist-backend:latest
        ports:
        - containerPort: 8000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: ai-receptionist-secrets
              key: DATABASE_URL
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: ai-receptionist-secrets
              key: REDIS_URL
        - name: SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: ai-receptionist-secrets
              key: SECRET_KEY
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: ai-receptionist
spec:
  selector:
    app: backend
  ports:
  - protocol: TCP
    port: 8000
    targetPort: 8000
  type: ClusterIP
EOF

    cat > deployment/kubernetes/production/frontend-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: ai-receptionist
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: ${ACR_LOGIN_SERVER}/ai-receptionist-frontend:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: ai-receptionist
spec:
  selector:
    app: frontend
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: LoadBalancer
EOF

    cat > deployment/kubernetes/production/hpa.yaml << EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
  namespace: ai-receptionist
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
EOF

    log_success "Kubernetes manifests created!"
}

# Deploy to Kubernetes
deploy_to_k8s() {
    log_info "Deploying to Kubernetes..."
    
    # Apply manifests
    kubectl apply -f deployment/kubernetes/production/namespace.yaml
    kubectl apply -f deployment/kubernetes/production/secrets.yaml
    kubectl apply -f deployment/kubernetes/production/backend-deployment.yaml
    kubectl apply -f deployment/kubernetes/production/frontend-deployment.yaml
    kubectl apply -f deployment/kubernetes/production/hpa.yaml
    
    # Wait for deployments
    kubectl rollout status deployment/backend -n ai-receptionist --timeout=300s
    kubectl rollout status deployment/frontend -n ai-receptionist --timeout=300s
    
    log_success "Deployment complete!"
}

# Setup ingress and SSL
setup_ingress() {
    log_info "Setting up ingress controller..."
    
    # Install NGINX ingress controller
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz
    
    # Install cert-manager for SSL
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    
    helm install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --set installCRDs=true
    
    log_success "Ingress and SSL setup complete!"
}

# Setup monitoring
setup_monitoring() {
    log_info "Setting up monitoring stack..."
    
    # Install Prometheus and Grafana
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    helm install monitoring prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --set grafana.adminPassword="$(openssl rand -base64 12)"
    
    log_success "Monitoring setup complete!"
}

# Display deployment info
show_deployment_info() {
    echo ""
    echo "🎉 Production Deployment Complete!"
    echo "=================================="
    echo ""
    
    # Get external IP
    EXTERNAL_IP=$(kubectl get service frontend-service -n ai-receptionist -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    echo "📊 Access URLs:"
    echo "  Frontend: http://${EXTERNAL_IP}"
    echo "  Backend API: http://${EXTERNAL_IP}/api"
    echo ""
    echo "🎛️ Management:"
    echo "  Kubectl: kubectl get pods -n ai-receptionist"
    echo "  Logs: kubectl logs -f deployment/backend -n ai-receptionist"
    echo "  Scale: kubectl scale deployment backend --replicas=5 -n ai-receptionist"
    echo ""
    echo "📊 Monitoring:"
    echo "  Grafana: kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring"
    echo "  Prometheus: kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring"
    echo ""
    echo "🔧 Azure Resources:"
    echo "  Resource Group: $RESOURCE_GROUP"
    echo "  AKS Cluster: $AKS_CLUSTER"
    echo "  Container Registry: $ACR_NAME"
    echo ""
    echo "💰 Estimated Monthly Cost: $1,500-3,000"
    echo "   (3 nodes + managed services + monitoring)"
}

# Main deployment
main() {
    check_prerequisites
    create_resource_group
    create_acr
    create_aks
    create_managed_services
    build_and_push
    create_k8s_manifests
    deploy_to_k8s
    setup_ingress
    setup_monitoring
    show_deployment_info
}

# Handle interruption
trap 'log_error "Deployment interrupted"; exit 1' INT

# Confirmation
echo "This will deploy AI Receptionist to Azure Kubernetes Service."
echo "This is a PRODUCTION deployment with:"
echo "  - Auto-scaling (1-10 nodes)"
echo "  - Managed PostgreSQL & Redis"
echo "  - Load balancing & SSL"
echo "  - Full monitoring stack"
echo ""
echo "Estimated cost: $1,500-3,000/month"
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 1
fi

# Run deployment
main
