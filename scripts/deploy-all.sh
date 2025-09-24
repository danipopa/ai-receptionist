#!/bin/bash

# AI Receptionist - Complete Kubernetes Deployment Script
# This script deploys all components in the correct order

set -e

NAMESPACE="ai-receptionist"
KUBECTL_CMD="kubectl"

echo "🚀 Starting AI Receptionist deployment..."

# Function to wait for deployment to be ready
wait_for_deployment() {
    local deployment=$1
    local timeout=${2:-300}
    
    echo "⏳ Waiting for $deployment to be ready..."
    if $KUBECTL_CMD wait --for=condition=available deployment/$deployment \
        --namespace=$NAMESPACE --timeout=${timeout}s; then
        echo "✅ $deployment is ready"
        return 0
    else
        echo "❌ $deployment failed to become ready within ${timeout}s"
        return 1
    fi
}

# Function to wait for statefulset to be ready
wait_for_statefulset() {
    local statefulset=$1
    local replicas=${2:-1}
    local timeout=${3:-300}
    
    echo "⏳ Waiting for $statefulset to be ready..."
    if $KUBECTL_CMD wait --for=jsonpath='{.status.readyReplicas}'=$replicas \
        statefulset/$statefulset --namespace=$NAMESPACE --timeout=${timeout}s; then
        echo "✅ $statefulset is ready"
        return 0
    else
        echo "❌ $statefulset failed to become ready within ${timeout}s"
        return 1
    fi
}

# Step 1: Deploy storage and infrastructure
echo "📦 Step 1: Deploying storage and infrastructure..."
$KUBECTL_CMD apply -f k8s-manifests/storage-class.yaml
$KUBECTL_CMD apply -f k8s-manifests/persistent-volumes.yaml

# Step 2: Deploy databases
echo "🗄️ Step 2: Deploying databases..."
$KUBECTL_CMD apply -f k8s-manifests/database/

echo "⏳ Waiting for databases to be ready..."
wait_for_statefulset "mysql" 1 600
wait_for_deployment "redis" 180

# Step 3: Deploy ConfigMaps and application services
echo "⚙️ Step 3: Deploying application services..."

# Deploy AI Engine
echo "🤖 Deploying AI Engine..."
$KUBECTL_CMD apply -f k8s-manifests/ai-engine/
wait_for_deployment "ai-engine" 300

# Deploy Backend API
echo "🔧 Deploying Backend API..."
$KUBECTL_CMD apply -f k8s-manifests/backend/
wait_for_deployment "backend-api" 300

# Deploy FreeSWITCH
echo "📞 Deploying FreeSWITCH..."
$KUBECTL_CMD apply -f k8s-manifests/freeswitch/configmap-xml.yaml
$KUBECTL_CMD apply -f k8s-manifests/freeswitch/
wait_for_deployment "freeswitch" 300

# Step 4: Deploy Frontend
echo "🌐 Step 4: Deploying Frontend..."
if [ -d "k8s-manifests/frontend" ]; then
    $KUBECTL_CMD apply -f k8s-manifests/frontend/
    wait_for_deployment "frontend" 300
else
    echo "⚠️ Frontend manifests not found, skipping..."
fi

# Step 5: Deploy Ingress
echo "🌍 Step 5: Deploying Ingress..."
if [ -f "k8s-manifests/ingress.yaml" ]; then
    $KUBECTL_CMD apply -f k8s-manifests/ingress.yaml
    echo "✅ Ingress deployed"
else
    echo "⚠️ Ingress manifest not found, skipping..."
fi

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📊 Current status:"
$KUBECTL_CMD get pods -n $NAMESPACE
echo ""
echo "🔍 Services:"
$KUBECTL_CMD get services -n $NAMESPACE
echo ""
echo "📈 HPA Status:"
$KUBECTL_CMD get hpa -n $NAMESPACE
echo ""
echo "✨ AI Receptionist is ready! ✨"