#!/bin/bash

# Cleanup script to fix existing PVC and StatefulSet conflicts
# This script removes existing resources that conflict with storage class changes

set -e

NAMESPACE="ai-receptionist"

echo "=== AI Receptionist Storage Cleanup ==="
echo "This script will clean up existing PVCs and StatefulSets that have storage class conflicts"
echo ""

# Function to check if resource exists
resource_exists() {
    kubectl get "$1" "$2" -n "$NAMESPACE" >/dev/null 2>&1
}

# 1. Check what needs to be cleaned up
echo "Checking existing resources in namespace: $NAMESPACE"
echo ""

if resource_exists "pvc" "redis-data-pvc"; then
    echo "❌ Found PVC: redis-data-pvc (needs cleanup)"
fi

if resource_exists "pvc" "mysql-data-mysql-0"; then
    echo "❌ Found PVC: mysql-data-mysql-0 (needs cleanup)"
fi

if resource_exists "statefulset" "mysql"; then
    echo "❌ Found StatefulSet: mysql (needs cleanup)"
fi

if resource_exists "deployment" "redis"; then
    echo "ℹ️  Found Deployment: redis (will be recreated)"
fi

echo ""
echo "Starting cleanup process..."
echo ""

# 2. Delete Redis deployment and PVC
if resource_exists "deployment" "redis"; then
    echo "🗑️  Deleting Redis deployment..."
    kubectl delete deployment redis -n "$NAMESPACE" --grace-period=0 --force
    echo "✅ Redis deployment deleted"
fi

if resource_exists "pvc" "redis-data-pvc"; then
    echo "🗑️  Deleting Redis PVC..."
    kubectl delete pvc redis-data-pvc -n "$NAMESPACE" --grace-period=0 --force
    echo "✅ Redis PVC deleted"
fi

# 3. Delete MySQL StatefulSet and PVC
if resource_exists "statefulset" "mysql"; then
    echo "🗑️  Deleting MySQL StatefulSet..."
    kubectl delete statefulset mysql -n "$NAMESPACE" --grace-period=0 --force
    echo "✅ MySQL StatefulSet deleted"
fi

if resource_exists "pvc" "mysql-data-mysql-0"; then
    echo "🗑️  Deleting MySQL PVC..."
    kubectl delete pvc mysql-data-mysql-0 -n "$NAMESPACE" --grace-period=0 --force
    echo "✅ MySQL PVC deleted"
fi

# 4. Wait for cleanup to complete
echo ""
echo "⏳ Waiting for resources to be fully deleted..."
sleep 10

# 5. Verify cleanup
echo ""
echo "🔍 Verifying cleanup completed..."

REMAINING_PVCS=$(kubectl get pvc -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
if [ "$REMAINING_PVCS" -eq 0 ]; then
    echo "✅ All PVCs cleaned up successfully"
else
    echo "⚠️  Some PVCs still exist:"
    kubectl get pvc -n "$NAMESPACE"
fi

# 6. Check PV status
echo ""
echo "📋 Current PersistentVolume status:"
kubectl get pv | grep -E "(mysql-pv|redis-pv|ai-receptionist)" || echo "No matching PVs found"

echo ""
echo "🎉 Cleanup completed!"
echo ""
echo "Next steps:"
echo "1. Run: ./deploy-k8s.sh deploy"
echo "2. Or manually apply: kubectl apply -f k8s-manifests/database/"
echo ""
echo "The PVCs will now be created with the correct 'local-storage' storage class"