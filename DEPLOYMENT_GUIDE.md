# Deployment Guide - Staging Server

## Prerequisites

1. SSH access to staging server
2. kubectl configured for staging cluster
3. Docker registry accessible from staging server

## Deployment Steps

### 1. Connect to Staging Server

```bash
# SSH to your staging server
ssh user@your-staging-server-ip
```

### 2. Pull Latest Code

```bash
cd /path/to/ai-receptionist
git pull origin main
```

### 3. Build and Push FreeSWITCH Server Image (if needed)

If your staging server has a different Docker registry:

```bash
# Build for staging registry
docker build -t YOUR_STAGING_REGISTRY/ai-receptionist/freeswitch-server:latest ./freeswitch-server/

# Push to staging registry
docker push YOUR_STAGING_REGISTRY/ai-receptionist/freeswitch-server:latest
```

Or, if using the same registry (176.9.65.80:5000), the image is already there!

### 4. Update Image References (if using different registry)

If your staging uses a different registry, update the image references:

```bash
# Update freeswitch deployment
sed -i 's|176.9.65.80:5000|YOUR_STAGING_REGISTRY|g' k8s-manifests/freeswitch/deployment.yaml
sed -i 's|176.9.65.80:5000|YOUR_STAGING_REGISTRY|g' k8s-manifests/ai-freeswitch/deployment.yaml
```

### 5. Deploy FreeSWITCH Server

```bash
# Create namespace if it doesn't exist
kubectl create namespace ai-receptionist --dry-run=client -o yaml | kubectl apply -f -

# Deploy FreeSWITCH server
kubectl apply -f k8s-manifests/freeswitch/deployment.yaml
kubectl apply -f k8s-manifests/freeswitch/service.yaml

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=freeswitch-server -n ai-receptionist --timeout=120s
```

### 6. Verify FreeSWITCH Server

```bash
# Check pod status
kubectl get pods -n ai-receptionist -l app=freeswitch-server

# Check logs
kubectl logs -n ai-receptionist -l app=freeswitch-server --tail=50

# Test Event Socket (should connect)
kubectl exec -it -n ai-receptionist deployment/freeswitch-server -- telnet localhost 8021
```

### 7. Deploy AI-FreeSWITCH Integration

```bash
# Deploy integration layer
kubectl apply -f k8s-manifests/ai-freeswitch/deployment.yaml
kubectl apply -f k8s-manifests/ai-freeswitch/service.yaml

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=ai-freeswitch -n ai-receptionist --timeout=120s
```

### 8. Verify AI-FreeSWITCH Integration

```bash
# Check pod status
kubectl get pods -n ai-receptionist -l app=ai-freeswitch

# Check logs (should show connection to FreeSWITCH)
kubectl logs -n ai-receptionist -l app=ai-freeswitch --tail=50

# Test health endpoint
kubectl port-forward -n ai-receptionist deployment/ai-freeswitch 8080:8080 &
curl http://localhost:8080/health
```

### 9. Deploy Backend Service (for external access)

```bash
kubectl apply -f k8s-manifests/backend/service.yaml
```

### 10. Verify Complete Stack

```bash
# Check all services
kubectl get svc -n ai-receptionist

# Check all pods
kubectl get pods -n ai-receptionist

# Check FreeSWITCH registration (from FreeSWITCH pod)
kubectl exec -it -n ai-receptionist deployment/freeswitch-server -- fs_cli -x "status"
```

## Quick Deployment Script

For future deployments, you can use this one-liner:

```bash
#!/bin/bash
set -e

echo "🚀 Deploying FreeSWITCH stack to staging..."

# Deploy FreeSWITCH server
kubectl apply -f k8s-manifests/freeswitch/deployment.yaml
kubectl apply -f k8s-manifests/freeswitch/service.yaml
echo "✓ FreeSWITCH server deployed"

# Wait for FreeSWITCH to be ready
kubectl wait --for=condition=ready pod -l app=freeswitch-server -n ai-receptionist --timeout=120s
echo "✓ FreeSWITCH server ready"

# Deploy AI integration
kubectl apply -f k8s-manifests/ai-freeswitch/deployment.yaml
kubectl apply -f k8s-manifests/ai-freeswitch/service.yaml
echo "✓ AI-FreeSWITCH integration deployed"

# Wait for integration to be ready
kubectl wait --for=condition=ready pod -l app=ai-freeswitch -n ai-receptionist --timeout=120s
echo "✓ AI-FreeSWITCH integration ready"

# Deploy backend service
kubectl apply -f k8s-manifests/backend/service.yaml
echo "✓ Backend service deployed"

# Show status
echo ""
echo "📊 Deployment Status:"
kubectl get pods -n ai-receptionist
echo ""
kubectl get svc -n ai-receptionist

echo ""
echo "✅ Deployment complete!"
```

Save this as `deploy-staging.sh` and make it executable:
```bash
chmod +x deploy-staging.sh
./deploy-staging.sh
```

## Rollback (if needed)

```bash
# Rollback FreeSWITCH server
kubectl rollout undo deployment/freeswitch-server -n ai-receptionist

# Rollback AI integration
kubectl rollout undo deployment/ai-freeswitch -n ai-receptionist
```

## Troubleshooting

### FreeSWITCH won't start
```bash
# Check logs
kubectl logs -n ai-receptionist -l app=freeswitch-server --tail=100

# Check events
kubectl describe pod -n ai-receptionist -l app=freeswitch-server

# Check if ports are in use
kubectl exec -it -n ai-receptionist deployment/freeswitch-server -- netstat -tulpn
```

### AI-FreeSWITCH can't connect
```bash
# Verify FreeSWITCH Event Socket is accessible
kubectl exec -it -n ai-receptionist deployment/freeswitch-server -- netstat -tulpn | grep 8021

# Test connectivity from ai-freeswitch pod
kubectl exec -it -n ai-receptionist deployment/ai-freeswitch -- nc -zv freeswitch-event-socket 8021

# Check DNS resolution
kubectl exec -it -n ai-receptionist deployment/ai-freeswitch -- nslookup freeswitch-event-socket
```

## Important Notes

- **Image Registry:** Make sure your staging server can access the Docker registry (176.9.65.80:5000)
- **LoadBalancer IPs:** Update the LoadBalancer IPs in `service.yaml` if staging uses different IPs
- **SignalWire Token:** The token is embedded in the image (secure it properly)
- **Scaling:** FreeSWITCH server uses `Recreate` strategy, can't scale horizontally without additional config
