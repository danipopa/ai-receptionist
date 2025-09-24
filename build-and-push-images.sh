#!/bin/bash

# Build and push Docker images for AI Receptionist
# Usage: ./build-and-push-images.sh [registry]

set -e

# Default to your private registry
REGISTRY=${1:-"176.9.65.80"}
VERSION="latest"

echo "🏗️  Building and pushing AI Receptionist images to $REGISTRY"
echo "=================================================="

# Function to build and push an image
build_and_push() {
    local service=$1
    local dockerfile_path=$2
    local context_path=$3
    local image_name="ai-receptionist/$service:$VERSION"
    local full_image="$REGISTRY/$image_name"
    
    echo "📦 Building $service..."
    echo "   Dockerfile: $dockerfile_path"
    echo "   Context: $context_path"
    echo "   Image: $full_image"
    
    # Build the image
    docker build -f "$dockerfile_path" -t "$image_name" -t "$full_image" "$context_path"
    
    # Push to registry
    echo "📤 Pushing $service to registry..."
    docker push "$full_image"
    
    echo "✅ $service completed!"
    echo ""
}

# Build and push all services
build_and_push "backend" "backend-ai-receptionist/Dockerfile" "backend-ai-receptionist"
build_and_push "ai-engine" "ai-engine/Dockerfile" "ai-engine"
build_and_push "freeswitch" "ai-freeswitch/Dockerfile" "ai-freeswitch"
build_and_push "frontend" "frontend-ai-receptionist/Dockerfile" "frontend-ai-receptionist"

echo "🎉 All images built and pushed successfully!"
echo ""
echo "Next steps:"
echo "1. Update Kubernetes manifests to use $REGISTRY prefix"
echo "2. Apply the updated manifests: kubectl apply -f k8s-manifests/"
echo "3. Check pod status: kubectl get pods -n ai-receptionist"