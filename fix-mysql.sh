#!/bin/bash

# Fix MySQL initialization and startup issues
# This script cleans up corrupt MySQL data and restarts the service

set -e

NAMESPACE="ai-receptionist"

echo "=== MySQL Fix Script ==="
echo "This script will fix MySQL startup issues by:"
echo "1. Updating MySQL configuration"
echo "2. Cleaning corrupt data directory"
echo "3. Restarting MySQL with fresh initialization"
echo ""

# 1. Delete the existing MySQL StatefulSet and PVC to start fresh
echo "🗑️  Cleaning up existing MySQL resources..."

if kubectl get statefulset mysql -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "Deleting MySQL StatefulSet..."
    kubectl delete statefulset mysql -n "$NAMESPACE" --grace-period=0 --force
fi

if kubectl get pvc mysql-data-mysql-0 -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "Deleting MySQL PVC (this will remove corrupt data)..."
    kubectl delete pvc mysql-data-mysql-0 -n "$NAMESPACE" --grace-period=0 --force
fi

# 2. Wait for cleanup
echo "⏳ Waiting for cleanup..."
sleep 5

# 3. Clear the storage directory on the host to ensure clean start
echo "🧹 Clearing storage directory..."
echo "Run this command on the k8svm node:"
echo "sudo rm -rf /home/storage/ns/ai-receptionist/mysql/*"
echo ""
echo "Press Enter after running the above command on k8svm..."
read -r

# 4. Apply updated configuration
echo "📝 Applying updated MySQL configuration..."
kubectl apply -f k8s-manifests/database/mysql.yaml

# 5. Wait for MySQL to start
echo "⏳ Waiting for MySQL to start..."
sleep 30

# 6. Check status
echo "🔍 Checking MySQL status..."
kubectl get pods -n "$NAMESPACE" -l app=mysql

echo ""
echo "Monitoring MySQL startup logs..."
kubectl logs -f mysql-0 -n "$NAMESPACE" || true

echo ""
echo "MySQL fix completed! Check the logs above for any issues."
echo ""
echo "If successful, MySQL should be running and ready to accept connections."