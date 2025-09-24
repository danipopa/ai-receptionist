#!/bin/bash

# Fix PersistentVolume conflicts for AI Receptionist deployment
# This script handles existing PVs that conflict with our deployment

set -e

echo "Fixing PersistentVolume conflicts..."

# Check if redis-pv exists and delete it if it has the wrong configuration
echo "Checking existing ai-receptionist-redis-pv..."
if kubectl get pv ai-receptionist-redis-pv >/dev/null 2>&1; then
    echo "Found existing ai-receptionist-redis-pv with incorrect configuration"
    
    # Check if it's bound to any PVC
    PV_STATUS=$(kubectl get pv ai-receptionist-redis-pv -o jsonpath='{.status.phase}')
    if [ "$PV_STATUS" = "Bound" ]; then
        echo "ERROR: ai-receptionist-redis-pv is bound to a PVC. Please delete the PVC first:"
        kubectl get pvc -A | grep redis
        echo "Run: kubectl delete pvc <pvc-name> -n <namespace>"
        echo "Then re-run this script."
        exit 1
    fi
    
    echo "Deleting existing ai-receptionist-redis-pv..."
    kubectl delete pv ai-receptionist-redis-pv
    echo "Existing ai-receptionist-redis-pv deleted"
else
    echo "No existing ai-receptionist-redis-pv found"
fi

# Also check for old redis-pv name and delete if exists
if kubectl get pv redis-pv >/dev/null 2>&1; then
    echo "Found old redis-pv, deleting..."
    kubectl delete pv redis-pv
    echo "Old redis-pv deleted"
fi

# Apply the storage class first
echo "Applying storage class..."
kubectl apply -f k8s-manifests/storage-class.yaml

# Apply the persistent volumes
echo "Creating persistent volumes..."
kubectl apply -f k8s-manifests/persistent-volumes.yaml

# Verify all PVs are created
echo "Verifying persistent volumes..."
kubectl get pv | grep -E "(ai-receptionist-mysql-pv|ai-receptionist-redis-pv|ai-receptionist-freeswitch-logs-pv|ai-receptionist-freeswitch-recordings-pv)"

echo ""
echo "PersistentVolume setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Make sure storage directories exist on the node:"
echo "   ./setup-storage.sh"
echo ""
echo "2. Deploy the application:"
echo "   ./deploy-k8s.sh deploy"