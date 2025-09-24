#!/bin/bash

# Fix PersistentVolume conflicts for AI Receptionist deployment
# This script handles existing PVs that conflict with our deployment

set -e

echo "Fixing PersistentVolume conflicts..."

# Check if redis-pv exists and delete it if it has the wrong configuration
echo "Checking existing redis-pv..."
if kubectl get pv redis-pv >/dev/null 2>&1; then
    echo "Found existing redis-pv with incorrect configuration"
    
    # Check if it's bound to any PVC
    PV_STATUS=$(kubectl get pv redis-pv -o jsonpath='{.status.phase}')
    if [ "$PV_STATUS" = "Bound" ]; then
        echo "ERROR: redis-pv is bound to a PVC. Please delete the PVC first:"
        kubectl get pvc -A | grep redis
        echo "Run: kubectl delete pvc <pvc-name> -n <namespace>"
        echo "Then re-run this script."
        exit 1
    fi
    
    echo "Deleting existing redis-pv..."
    kubectl delete pv redis-pv
    echo "Existing redis-pv deleted"
else
    echo "No existing redis-pv found"
fi

# Apply the storage class first
echo "Applying storage class..."
kubectl apply -f k8s-manifests/storage-class.yaml

# Apply the persistent volumes
echo "Creating persistent volumes..."
kubectl apply -f k8s-manifests/persistent-volumes.yaml

# Verify all PVs are created
echo "Verifying persistent volumes..."
kubectl get pv | grep -E "(mysql-pv|redis-pv|freeswitch-logs-pv|freeswitch-recordings-pv)"

echo ""
echo "PersistentVolume setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Make sure storage directories exist on the node:"
echo "   ./setup-storage.sh"
echo ""
echo "2. Deploy the application:"
echo "   ./deploy-k8s.sh deploy"