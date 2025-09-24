# FreeSWITCH on Kubernetes - AI Receptionist Deployment

This guide covers deploying the AI Receptionist FreeSWITCH system on Kubernetes for production use.

## Architecture Overview

The Kubernetes deployment consists of:

- **FreeSWITCH Pods**: Handle SIP/RTP telephony traffic with AI integration
- **AI Engine Pods**: Process speech-to-text, conversation AI, and text-to-speech
- **Backend API Pods**: Manage customers, phone numbers, FAQs, and call transcripts
- **MySQL StatefulSet**: Primary database with persistent storage
- **Redis Deployment**: Session cache and real-time data
- **Load Balancers**: External access for SIP/RTP traffic
- **Ingress Controller**: HTTPS access for management APIs

## Prerequisites

### Software Requirements
- Kubernetes cluster (1.25+)
- kubectl CLI tool
- Docker (for building images)
- Helm (optional, for easier management)

### Cluster Requirements
- **CPU**: Minimum 8 cores (16+ recommended)
- **Memory**: Minimum 16GB RAM (32GB+ recommended)  
- **Storage**: 100GB+ available storage with dynamic provisioning
- **Network**: LoadBalancer support (cloud provider or MetalLB)
- **Ingress**: NGINX Ingress Controller installed

### Networking Requirements
- **SIP Port**: 5060/UDP accessible from external SIP providers
- **RTP Ports**: 16384-32768/UDP range for media traffic
- **HTTPS**: 443/TCP for management APIs
- **Static IPs**: Recommended for SIP/RTP services

## Quick Deployment

### 1. Clone and Prepare
```bash
git clone <your-repo>
cd ai-receptionis
```

### 2. Configure Secrets
Update the base64 encoded secrets in the manifest files:

```bash
# Generate secrets
echo -n "your-openai-api-key" | base64
echo -n "your-mysql-password" | base64
echo -n "your-redis-password" | base64
echo -n "$(openssl rand -hex 64)" | base64  # Rails secret key base
```

Update these files with your base64 encoded values:
- `k8s-manifests/ai-engine/deployment.yaml` - OpenAI API key
- `k8s-manifests/backend/deployment.yaml` - MySQL password, Rails secret
- `k8s-manifests/database/mysql.yaml` - MySQL root and user passwords
- `k8s-manifests/database/redis.yaml` - Redis password

### 3. Deploy Everything
```bash
# Full deployment (builds images + deploys to k8s)
./deploy-k8s.sh

# Or step by step:
./deploy-k8s.sh build    # Build Docker images
./deploy-k8s.sh deploy   # Deploy to Kubernetes
./deploy-k8s.sh status   # Check deployment status
```

### 4. Configure DNS
Point your domains to the ingress IP addresses:

```bash
# Get ingress IPs
./deploy-k8s.sh endpoints

# Update DNS records:
# api.ai-receptionist.your-domain.com -> INGRESS_IP
# freeswitch.ai-receptionist.your-domain.com -> INGRESS_IP
```

## Detailed Configuration

### FreeSWITCH Configuration

The FreeSWITCH deployment includes:
- **Replicas**: 2 pods for high availability
- **SIP Configuration**: Internal profile on port 5060
- **RTP Range**: 16384-32768 for media
- **AI Integration**: Socket connection to AI engine
- **Load Balancing**: UDP LoadBalancer with session affinity

Key configuration files:
- `k8s-manifests/freeswitch/configmap.yaml` - FreeSWITCH XML config
- `k8s-manifests/freeswitch/deployment.yaml` - Pod specifications
- `k8s-manifests/freeswitch/service.yaml` - Networking services

### AI Engine Configuration

- **Replicas**: 3 pods with horizontal auto-scaling (3-10)
- **OpenAI Integration**: Requires valid API key
- **Resource Limits**: 4GB RAM, 2 CPU cores per pod
- **Auto-scaling**: Based on CPU (70%) and memory (80%)

### Backend API Configuration

- **Replicas**: 3 pods with auto-scaling
- **Database**: MySQL with persistent storage
- **Cache**: Redis for session management
- **Migrations**: Automatic database migration on deployment
- **Health Checks**: Liveness and readiness probes

### Database Configuration

**MySQL StatefulSet**:
- **Storage**: 50GB persistent volume
- **Configuration**: Optimized for production workloads
- **Backup**: Consider setting up automated backups
- **Replication**: Single instance (add read replicas for scale)

**Redis Deployment**:
- **Storage**: 10GB persistent volume  
- **Memory**: 512MB max memory with LRU eviction
- **Persistence**: AOF + RDB snapshots

## Networking and Security

### LoadBalancer Services

**SIP Service** (`freeswitch-sip`):
- **Type**: LoadBalancer with UDP protocol
- **Port**: 5060/UDP
- **Session Affinity**: ClientIP (for SIP session continuity)
- **External Traffic Policy**: Local (preserve source IP)

**RTP Service** (`freeswitch-rtp`):  
- **Type**: LoadBalancer with UDP protocol
- **Ports**: 16384-16388/UDP (example subset)
- **Session Affinity**: ClientIP
- **Note**: Adjust port range based on concurrent call requirements

### Network Policies

- **Default Deny**: All traffic denied by default
- **Ingress Rules**: Allow specific ports and sources
- **Inter-Service**: Allow communication within namespace
- **External Access**: Allow SIP/RTP from internet

### Security Considerations

1. **TLS Termination**: HTTPS at ingress level
2. **Secret Management**: Use Kubernetes secrets (consider Vault)
3. **RBAC**: Minimal permissions for service accounts
4. **Pod Security**: Non-root containers, security contexts
5. **Network Segmentation**: NetworkPolicies for traffic control

## Monitoring and Observability

### Health Checks

All services include:
- **Liveness Probes**: Detect failed pods for restart
- **Readiness Probes**: Control traffic to healthy pods only  
- **Startup Probes**: Allow time for application initialization

### Recommended Monitoring Stack

```bash
# Install Prometheus and Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# Add custom dashboards for:
# - FreeSWITCH call metrics
# - AI engine response times  
# - Database performance
# - SIP registration status
```

### Logging

Consider centralizing logs with:
- **ELK Stack**: Elasticsearch, Logstash, Kibana
- **Loki**: Grafana's log aggregation system
- **Fluentd**: Log collection and forwarding

### Metrics to Monitor

- **SIP Registrations**: Active registrations per pod
- **Call Success Rate**: Completed vs failed calls
- **AI Response Time**: Time to generate responses
- **RTP Quality**: Packet loss, jitter, latency
- **Database Performance**: Query times, connections
- **Pod Resource Usage**: CPU, memory, network

## Scaling and Performance

### Horizontal Pod Autoscaling

Configured for:
- **AI Engine**: 3-10 replicas based on CPU/memory
- **Backend API**: 3-10 replicas based on CPU/memory  
- **FreeSWITCH**: Manual scaling (consider call capacity)

### Vertical Scaling

Adjust resource requests/limits based on:
- **FreeSWITCH**: CPU for call processing, memory for call state
- **AI Engine**: Memory for model loading, CPU for inference
- **Backend API**: Memory for Rails app, CPU for request processing

### Performance Tuning

**FreeSWITCH**:
```yaml
# Increase for high call volumes
resources:
  requests:
    cpu: "1000m"
    memory: "2Gi" 
  limits:
    cpu: "2000m"
    memory: "4Gi"
```

**MySQL**:
```ini
# Tune for your workload
innodb_buffer_pool_size = 4G  # 70-80% of available RAM
max_connections = 1000
innodb_log_file_size = 512M
```

## Backup and Disaster Recovery

### Database Backups

```bash
# Set up automated MySQL backups
kubectl create job mysql-backup --from=cronjob/mysql-backup -n ai-receptionist

# Backup script example:
mysqldump --single-transaction --routines --triggers \
  -h mysql -u root -p$MYSQL_ROOT_PASSWORD \
  ai_receptionist_production > backup-$(date +%Y%m%d).sql
```

### Configuration Backups

```bash
# Backup all Kubernetes manifests
kubectl get all,configmaps,secrets,pvc -n ai-receptionist -o yaml > backup-k8s.yaml
```

### Disaster Recovery Plan

1. **RTO/RPO Targets**: Define acceptable downtime and data loss
2. **Multi-Zone Deployment**: Spread pods across availability zones
3. **External Backups**: Store backups outside the cluster
4. **Runbook**: Document recovery procedures step-by-step

## Troubleshooting

### Common Issues

**SIP Registration Failures**:
```bash
# Check FreeSWITCH logs
kubectl logs -f deployment/freeswitch -n ai-receptionist

# Verify external IP and DNS
kubectl get service freeswitch-sip -n ai-receptionist
nslookup your-sip-domain.com
```

**RTP Audio Issues**:
```bash
# Check RTP port accessibility
kubectl get service freeswitch-rtp -n ai-receptionist

# Verify firewall rules allow UDP 16384-32768
# Check NAT/network configuration
```

**AI Engine Errors**:
```bash
# Check AI engine logs and API key
kubectl logs -f deployment/ai-engine -n ai-receptionist

# Verify OpenAI API key is valid
kubectl get secret ai-engine-secrets -n ai-receptionist -o yaml
```

**Database Connection Issues**:
```bash  
# Check MySQL pod status
kubectl get pods -l app=mysql -n ai-receptionist

# Test database connectivity
kubectl exec -it deployment/backend-api -n ai-receptionist -- \
  bundle exec rails runner "puts ActiveRecord::Base.connection.active?"
```

### Debug Commands

```bash
# Get pod details
kubectl describe pod <pod-name> -n ai-receptionist

# Check resource usage
kubectl top pods -n ai-receptionist

# View events
kubectl get events -n ai-receptionist --sort-by='.lastTimestamp'

# Port forward for local testing
kubectl port-forward service/freeswitch-api 8080:8080 -n ai-receptionist
kubectl port-forward service/backend-api 3000:3000 -n ai-receptionist
```

## Production Readiness Checklist

- [ ] **Security**: All secrets properly configured
- [ ] **TLS**: Valid SSL certificates installed
- [ ] **DNS**: Domain names pointing to correct IPs
- [ ] **Monitoring**: Prometheus/Grafana deployed and configured
- [ ] **Logging**: Centralized logging solution active
- [ ] **Backups**: Automated backup system configured
- [ ] **Scaling**: HPA and resource limits properly set
- [ ] **Testing**: End-to-end call testing completed
- [ ] **Documentation**: Runbooks and procedures documented
- [ ] **Alerts**: Critical alerts configured and tested
- [ ] **Disaster Recovery**: Recovery procedures tested

## Support and Maintenance

### Regular Maintenance Tasks

- **Weekly**: Review logs, check resource usage
- **Monthly**: Update container images, backup verification
- **Quarterly**: Security updates, capacity planning  
- **Annually**: Disaster recovery testing, architecture review

### Version Updates

```bash
# Update container images
docker build -t ai-receptionist/freeswitch:v1.1 ./ai-freeswitch/
kubectl set image deployment/freeswitch freeswitch=ai-receptionist/freeswitch:v1.1 -n ai-receptionist

# Rolling update will deploy new version with zero downtime
kubectl rollout status deployment/freeswitch -n ai-receptionist

# Rollback if needed
kubectl rollout undo deployment/freeswitch -n ai-receptionist
```

This deployment provides a production-ready, scalable FreeSWITCH solution with AI integration, suitable for handling thousands of concurrent calls with high availability and observability.