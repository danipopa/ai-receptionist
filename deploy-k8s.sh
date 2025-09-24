#!/bin/bash

# AI Receptionist Kubernetes Deployment Script
# This script deploys the complete AI receptionist system to Kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="ai-receptionist"
KUBECTL="kubectl"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check if namespace exists
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        log_warning "Namespace $NAMESPACE already exists"
    fi
    
    log_success "Prerequisites check passed"
}

# Build and push Docker images
build_images() {
    log_info "Building Docker images..."
    
    # Build backend image
    log_info "Building backend-ai-receptionist image..."
    docker build -t ai-receptionist/backend:latest ./backend-ai-receptionist/
    
    # Build ai-engine image
    log_info "Building ai-engine image..."
    docker build -t ai-receptionist/ai-engine:latest ./ai-engine/
    
    # Build freeswitch image
    log_info "Building freeswitch image..."
    docker build -t ai-receptionist/freeswitch:latest ./ai-freeswitch/
    
    log_success "Docker images built successfully"
}

# Deploy to Kubernetes
deploy_to_k8s() {
    log_info "Deploying to Kubernetes..."
    
    # Create namespace first
    log_info "Creating namespace..."
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Create storage class and persistent volumes
    log_info "Setting up storage..."
    kubectl apply -f k8s-manifests/storage-class.yaml
    kubectl apply -f k8s-manifests/persistent-volumes.yaml
    
    # Create configmaps
    log_info "Creating configmaps..."
    kubectl apply -f k8s-manifests/freeswitch/configmap.yaml
    
    # Deploy databases first
    log_info "Deploying databases..."
    kubectl apply -f k8s-manifests/database/
    
    # Wait for databases to be ready
    log_info "Waiting for MySQL to be ready..."
    kubectl wait --for=condition=ready pod -l app=mysql -n $NAMESPACE --timeout=300s
    
    log_info "Waiting for Redis to be ready..."
    kubectl wait --for=condition=ready pod -l app=redis -n $NAMESPACE --timeout=300s
    
    # Deploy backend API
    log_info "Deploying backend API..."
    kubectl apply -f k8s-manifests/backend/
    
    # Wait for backend to be ready
    log_info "Waiting for backend API to be ready..."
    kubectl wait --for=condition=ready pod -l app=backend-api -n $NAMESPACE --timeout=300s
    
    # Deploy AI engine
    log_info "Deploying AI engine..."
    kubectl apply -f k8s-manifests/ai-engine/
    
    # Wait for AI engine to be ready
    log_info "Waiting for AI engine to be ready..."
    kubectl wait --for=condition=ready pod -l app=ai-engine -n $NAMESPACE --timeout=300s
    
    # Deploy FreeSWITCH
    log_info "Deploying FreeSWITCH..."
    kubectl apply -f k8s-manifests/freeswitch/
    
    # Wait for FreeSWITCH to be ready
    log_info "Waiting for FreeSWITCH to be ready..."
    kubectl wait --for=condition=ready pod -l app=freeswitch -n $NAMESPACE --timeout=300s
    
    # Deploy ingress and networking
    log_info "Deploying ingress and networking..."
    kubectl apply -f k8s-manifests/ingress.yaml
    
    log_success "Deployment completed successfully"
}

# Display deployment status
show_status() {
    log_info "Deployment Status:"
    echo ""
    
    # Show pods
    echo "Pods:"
    kubectl get pods -n $NAMESPACE -o wide
    echo ""
    
    # Show services
    echo "Services:"
    kubectl get services -n $NAMESPACE
    echo ""
    
    # Show ingress
    echo "Ingress:"
    kubectl get ingress -n $NAMESPACE
    echo ""
    
    # Show persistent volumes
    echo "Persistent Volumes:"
    kubectl get pvc -n $NAMESPACE
    echo ""
}

# Get external IPs and endpoints
get_endpoints() {
    log_info "Getting external endpoints..."
    echo ""
    
    # Get LoadBalancer IPs
    SIP_IP=$(kubectl get service freeswitch-sip -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    RTP_IP=$(kubectl get service freeswitch-rtp -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ -n "$SIP_IP" ]; then
        log_success "FreeSWITCH SIP endpoint: $SIP_IP:5060"
    else
        log_warning "FreeSWITCH SIP LoadBalancer IP not yet assigned"
    fi
    
    if [ -n "$RTP_IP" ]; then
        log_success "FreeSWITCH RTP endpoint: $RTP_IP:16384-32768"
    else
        log_warning "FreeSWITCH RTP LoadBalancer IP not yet assigned"
    fi
    
    # Get ingress endpoints
    INGRESS_IP=$(kubectl get ingress ai-receptionist-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ -n "$INGRESS_IP" ]; then
        log_success "API endpoint: https://api.ai-receptionist.your-domain.com (IP: $INGRESS_IP)"
        log_success "FreeSWITCH management: https://freeswitch.ai-receptionist.your-domain.com (IP: $INGRESS_IP)"
    else
        log_warning "Ingress IP not yet assigned"
    fi
    
    echo ""
}

# Main deployment function
main() {
    log_info "Starting AI Receptionist Kubernetes Deployment"
    echo ""
    
    check_prerequisites
    build_images
    deploy_to_k8s
    show_status
    get_endpoints
    
    log_success "AI Receptionist deployment completed!"
    log_info "Configure your SIP clients to connect to the FreeSWITCH SIP endpoint"
    log_info "Update DNS records to point to the ingress IP addresses"
}

# Handle script arguments
case "${1:-}" in
    "build")
        build_images
        ;;
    "deploy")
        deploy_to_k8s
        ;;
    "status")
        show_status
        ;;
    "endpoints")
        get_endpoints
        ;;
    "")
        main
        ;;
    *)
        echo "Usage: $0 [build|deploy|status|endpoints]"
        echo ""
        echo "Commands:"
        echo "  build     - Build Docker images only"
        echo "  deploy    - Deploy to Kubernetes only"
        echo "  status    - Show deployment status"
        echo "  endpoints - Show external endpoints"
        echo "  (no args) - Full deployment (build + deploy + status)"
        exit 1
        ;;
esac