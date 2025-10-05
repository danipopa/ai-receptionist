# AI Receptionist Kubernetes Deployment Steps

This guide provides the complete step-by-step process to deploy the AI Receptionist system with FreeSWITCH on Kubernetes using the `ai-receptionist` namespace.

## Prerequisites Verification

Before starting, ensure you have:

### 1. Kubernetes Cluster Ready
```bash
# Check cluster connection
kubectl cluster-info

# Verify nodes are ready
kubectl get nodes

# Check available resources
kubectl top nodes
```

### 2. Required Tools Installed
```bash
# Verify kubectl
kubectl version --client

# Verify Docker (for building images)
docker --version

# Check cluster permissions
kubectl auth can-i create pods --namespace=ai-receptionist
```

### 3. Cluster Requirements Met
- **Minimum**: 8 CPU cores, 16GB RAM, 100GB storage
- **LoadBalancer support** (cloud provider or MetalLB)
- **Ingress Controller** (NGINX recommended)
- **Storage class** for dynamic provisioning

## Step 1: Prepare Configuration

### Update Secrets (REQUIRED)

Generate your base64 encoded secrets:

```bash
# Generate OpenAI API key (base64)
echo -n "your-openai-api-key-here" | base64

# Generate MySQL passwords (base64)  
echo -n "your-secure-mysql-password" | base64

# Generate Rails secret key (base64)
echo -n "$(openssl rand -hex 64)" | base64

# Generate Redis password (base64)
echo -n "your-redis-password" | base64
```

### Update Secret Files

Edit these files with your base64 encoded values:

1. **AI Engine Secret** - `k8s-manifests/ai-engine/deployment.yaml`:
   ```bash
   # Find and replace the openai-api-key value
   vim k8s-manifests/ai-engine/deployment.yaml
   # Look for: data.openai-api-key: YOUR_BASE64_ENCODED_KEY
   ```

2. **Backend API Secrets** - `k8s-manifests/backend/deployment.yaml`:
   ```bash
   vim k8s-manifests/backend/deployment.yaml
   # Update:
   # - mysql-password: YOUR_BASE64_MYSQL_PASSWORD
   # - secret-key-base: YOUR_BASE64_RAILS_SECRET
   ```

3. **MySQL Secrets** - `k8s-manifests/database/mysql.yaml`:
   ```bash
   vim k8s-manifests/database/mysql.yaml
   # Update:
   # - mysql-root-password: YOUR_BASE64_ROOT_PASSWORD
   # - mysql-password: YOUR_BASE64_USER_PASSWORD
   ```

4. **Redis Secret** - `k8s-manifests/database/redis.yaml`:
   ```bash
   vim k8s-manifests/database/redis.yaml
   # Update:
   # - redis-password: YOUR_BASE64_REDIS_PASSWORD
   ```

## Step 2: Build Docker Images

Navigate to the project root and build all images:

```bash
cd /Users/dani/Development/ai-receptionis

# Build all images (automated)
./deploy-k8s.sh build
```

Or build manually:

```bash
# Build FreeSWITCH image
docker build -t ai-receptionist/freeswitch:latest ./ai-freeswitch/

# Build AI Engine image  
docker build -t ai-receptionist/ai-engine:latest ./ai-engine/

# Build Backend API image
docker build -t ai-receptionist/backend:latest ./backend-ai-receptionist/

# Verify images
docker images | grep ai-receptionist
```

## Step 3: Deploy to Kubernetes

### Option A: Full Automated Deployment (Recommended)

```bash
# Deploy everything with automated script
./deploy-k8s.sh deploy

# Monitor deployment progress
./deploy-k8s.sh status

# Get service endpoints when ready
./deploy-k8s.sh endpoints
```

### Option B: Manual Step-by-Step Deployment

```bash
# 1. Create namespace
kubectl create namespace ai-receptionist

# 2. Deploy infrastructure (databases first)
kubectl apply -f k8s-manifests/database/mysql.yaml
kubectl apply -f k8s-manifests/database/redis.yaml

# Wait for databases to be ready
kubectl wait --for=condition=ready pod -l app=mysql -n ai-receptionist --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n ai-receptionist --timeout=300s

# 3. Deploy application services
kubectl apply -f k8s-manifests/backend/deployment.yaml
kubectl apply -f k8s-manifests/ai-engine/deployment.yaml

# Wait for backend services
kubectl wait --for=condition=ready pod -l app=backend-api -n ai-receptionist --timeout=300s
kubectl wait --for=condition=ready pod -l app=ai-engine -n ai-receptionist --timeout=300s

# 4. Deploy FreeSWITCH
kubectl apply -f k8s-manifests/freeswitch/

# Wait for FreeSWITCH
kubectl wait --for=condition=ready pod -l app=freeswitch -n ai-receptionist --timeout=300s

# 5. Deploy networking
kubectl apply -f k8s-manifests/ingress.yaml
```

## Step 4: Verify Deployment

### Check Pod Status
```bash
# All pods should be Running
kubectl get pods -n ai-receptionist -o wide

# Expected output:
# NAME                          READY   STATUS    RESTARTS   AGE
# ai-engine-xxx                 1/1     Running   0          5m
# backend-api-xxx               1/1     Running   0          5m  
# freeswitch-xxx                1/1     Running   0          3m
# mysql-0                       1/1     Running   0          8m
# redis-xxx                     1/1     Running   0          8m
```

### Check Services
```bash
# Verify all services have endpoints
kubectl get services -n ai-receptionist

# Check external IPs for LoadBalancer services
kubectl get services -l type=LoadBalancer -n ai-receptionist
```

### Check Storage
```bash
# Verify persistent volumes are bound
kubectl get pvc -n ai-receptionist

# Expected output:
# NAME                    STATUS   VOLUME    CAPACITY   ACCESS MODES
# mysql-storage-mysql-0   Bound    pvc-xxx   50Gi       RWO
# redis-storage-redis-0   Bound    pvc-xxx   10Gi       RWO
```

## Step 5: Configure External Access

### Get External IPs
```bash
# Get all external endpoints
./deploy-k8s.sh endpoints

# Or manually:
kubectl get service freeswitch-sip -n ai-receptionist -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
kubectl get service freeswitch-rtp -n ai-receptionist -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
kubectl get ingress ai-receptionist-ingress -n ai-receptionist -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Configure DNS Records

Point your domain names to the external IPs:

```bash
# SIP Domain (for SIP registration)
# sip.mobiletel.eu -> SIP_EXTERNAL_IP

# API Domain (for management interface)  
# api.mobiletel.eu -> INGRESS_IP

# FreeSWITCH Management
# freeswitch.mobiletel.eu -> INGRESS_IP
```

### Configure SSL/TLS (Production)

```bash
# Install cert-manager for automatic SSL
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer for Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@domain.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Update ingress to use SSL
kubectl patch ingress ai-receptionist-ingress -n ai-receptionist --type='json' -p='[{
  "op": "add",
  "path": "/metadata/annotations/cert-manager.io~1cluster-issuer",
  "value": "letsencrypt-prod"
}]'
```

## Step 6: Test the Deployment

### Test Database Connectivity
```bash
# Test MySQL connection
kubectl exec -it deployment/backend-api -n ai-receptionist -- \
  bundle exec rails runner "puts ActiveRecord::Base.connection.active?"

# Test Redis connection  
kubectl exec -it deployment/backend-api -n ai-receptionist -- \
  bundle exec rails runner "puts Redis.current.ping"
```

### Test API Endpoints
```bash
# Test backend API health
curl https://api.mobiletel.eu/api/v1/customers

# Test AI Engine health
curl https://api.mobiletel.eu/ai/health
```

### Test FreeSWITCH
```bash
# Check FreeSWITCH status
kubectl exec -it deployment/freeswitch -n ai-receptionist -- \
  fs_cli -x "status"

# Check SIP profile
kubectl exec -it deployment/freeswitch -n ai-receptionist -- \
  fs_cli -x "sofia status profile internal"
```

### Test SIP Registration
```bash
# Configure a SIP client with:
# - SIP Server: SIP_EXTERNAL_IP:5060
# - Username/Password: As configured in FreeSWITCH
# - Domain: Your SIP domain

# Check registrations in FreeSWITCH
kubectl exec -it deployment/freeswitch -n ai-receptionist -- \
  fs_cli -x "sofia status profile internal reg"
```

## Step 7: Monitor and Maintain

### Enable Monitoring (Recommended)
```bash
# Install Prometheus and Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace

# Access Grafana
kubectl port-forward service/monitoring-grafana 3000:80 -n monitoring
# Open http://localhost:3000 (admin/prom-operator)
```

### Regular Health Checks
```bash
# Check system status
./deploy-k8s.sh status

# Check resource usage
kubectl top pods -n ai-receptionist
kubectl top nodes

# Check logs for errors
kubectl logs -f deployment/freeswitch -n ai-receptionist
kubectl logs -f deployment/ai-engine -n ai-receptionist  
kubectl logs -f deployment/backend-api -n ai-receptionist
```

### Backup Strategy
```bash
# Database backup
kubectl exec mysql-0 -n ai-receptionist -- \
  mysqldump --single-transaction --routines --triggers \
  -u root -p$MYSQL_ROOT_PASSWORD ai_receptionist_production > backup-$(date +%Y%m%d).sql

# Configuration backup
kubectl get all,configmaps,secrets,pvc -n ai-receptionist -o yaml > k8s-backup.yaml
```

## Troubleshooting

If you encounter issues, refer to:
- `TROUBLESHOOTING.md` for detailed problem resolution
- `KUBERNETES-DEPLOYMENT.md` for comprehensive deployment documentation

### Quick Debug Commands
```bash
# Check pod logs
kubectl logs -f deployment/DEPLOYMENT_NAME -n ai-receptionist

# Get pod details
kubectl describe pod POD_NAME -n ai-receptionist

# Access pod shell
kubectl exec -it deployment/DEPLOYMENT_NAME -n ai-receptionist -- bash

# Check events
kubectl get events -n ai-receptionist --sort-by='.lastTimestamp'
```

## Production Checklist

Before going live:

- [ ] All secrets properly configured with strong passwords
- [ ] SSL/TLS certificates installed and valid
- [ ] DNS records pointing to correct external IPs
- [ ] Monitoring and alerting configured  
- [ ] Backup strategy implemented and tested
- [ ] Resource limits and HPA configured appropriately
- [ ] Network security policies reviewed
- [ ] Disaster recovery procedures documented
- [ ] End-to-end call testing completed
- [ ] Performance testing under expected load

## Scaling Considerations

### Horizontal Scaling
```bash
# Scale specific deployments
kubectl scale deployment ai-engine --replicas=5 -n ai-receptionist
kubectl scale deployment backend-api --replicas=5 -n ai-receptionist

# Scale FreeSWITCH (consider call capacity)
kubectl scale deployment freeswitch --replicas=3 -n ai-receptionist
```

### Vertical Scaling
```bash
# Increase resources for high-traffic components
kubectl patch deployment ai-engine -n ai-receptionist -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "ai-engine", 
          "resources": {
            "requests": {"cpu": "2000m", "memory": "4Gi"},
            "limits": {"cpu": "4000m", "memory": "8Gi"}
          }
        }]
      }
    }
  }
}'
```

Your AI Receptionist system is now deployed on Kubernetes using the `ai-receptionist` namespace and ready for production use!