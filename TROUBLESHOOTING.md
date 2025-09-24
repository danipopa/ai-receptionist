# FreeSWITCH AI Receptionist - Troubleshooting Guide

This guide covers common issues and solutions when deploying and operating the AI Receptionist system on Kubernetes.

## Quick Diagnostics

### System Health Check
```bash
# Check overall system status
./deploy-k8s.sh status

# Check all pods
kubectl get pods -n ai-receptionist -o wide

# Check services and endpoints
kubectl get services,endpoints -n ai-receptionist
```

### Get Service Information
```bash
# Get external IPs and ports
./deploy-k8s.sh endpoints

# Check ingress status
kubectl get ingress -n ai-receptionist
kubectl describe ingress ai-receptionist-ingress -n ai-receptionist
```

## FreeSWITCH Issues

### SIP Registration Problems

**Symptoms:**
- SIP phones can't register
- "Registration timeout" errors
- No incoming calls reaching FreeSWITCH

**Diagnostics:**
```bash
# Check FreeSWITCH pod status
kubectl get pods -l app=freeswitch -n ai-receptionist

# View FreeSWITCH logs
kubectl logs -f deployment/freeswitch -n ai-receptionist

# Check SIP service external IP
kubectl get service freeswitch-sip -n ai-receptionist

# Test SIP port connectivity
nc -u EXTERNAL_IP 5060
```

**Common Solutions:**

1. **External IP not assigned:**
   ```bash
   # Check LoadBalancer service status
   kubectl describe service freeswitch-sip -n ai-receptionist
   
   # If stuck in "Pending", check cloud provider LoadBalancer quota
   # Or install MetalLB for on-premises clusters
   ```

2. **Firewall blocking SIP traffic:**
   ```bash
   # Ensure UDP port 5060 is open from internet
   # Check cloud provider security groups/firewall rules
   
   # Test from external location:
   telnet EXTERNAL_IP 5060
   nmap -sU -p 5060 EXTERNAL_IP
   ```

3. **DNS issues:**
   ```bash
   # Verify DNS points to correct IP
   nslookup your-sip-domain.com
   dig your-sip-domain.com
   
   # Update DNS records if needed
   ```

4. **FreeSWITCH configuration:**
   ```bash
   # Check FreeSWITCH config
   kubectl get configmap freeswitch-config -n ai-receptionist -o yaml
   
   # Edit and restart if needed
   kubectl edit configmap freeswitch-config -n ai-receptionist
   kubectl rollout restart deployment/freeswitch -n ai-receptionist
   ```

### RTP/Audio Issues

**Symptoms:**
- Calls connect but no audio
- One-way audio problems
- Poor call quality

**Diagnostics:**
```bash
# Check RTP service status
kubectl get service freeswitch-rtp -n ai-receptionist

# View FreeSWITCH RTP logs
kubectl logs deployment/freeswitch -n ai-receptionist | grep -i rtp

# Check pod networking
kubectl exec -it deployment/freeswitch -n ai-receptionist -- netstat -tuln
```

**Solutions:**

1. **RTP ports not accessible:**
   ```bash
   # Ensure UDP ports 16384-32768 are open
   # Check LoadBalancer configuration
   kubectl describe service freeswitch-rtp -n ai-receptionist
   
   # Test RTP port range
   nmap -sU -p 16384-16388 EXTERNAL_IP
   ```

2. **NAT/Network issues:**
   ```bash
   # Check if pods can reach external network
   kubectl exec -it deployment/freeswitch -n ai-receptionist -- ping 8.8.8.8
   
   # Verify external traffic policy
   kubectl patch service freeswitch-rtp -n ai-receptionist \
     -p '{"spec":{"externalTrafficPolicy":"Local"}}'
   ```

3. **Kubernetes network policy blocking:**
   ```bash
   # Check network policies
   kubectl get networkpolicy -n ai-receptionist
   
   # Temporarily disable for testing
   kubectl delete networkpolicy ai-receptionist-network-policy -n ai-receptionist
   ```

### FreeSWITCH Pod Crashes

**Symptoms:**
- FreeSWITCH pods restarting frequently
- Memory or CPU issues
- "CrashLoopBackOff" status

**Diagnostics:**
```bash
# Check pod events
kubectl describe pod FREESWITCH_POD_NAME -n ai-receptionist

# Check resource usage
kubectl top pod FREESWITCH_POD_NAME -n ai-receptionist

# View previous container logs
kubectl logs FREESWITCH_POD_NAME -n ai-receptionist --previous
```

**Solutions:**

1. **Resource limits too low:**
   ```bash
   # Increase resource limits
   kubectl patch deployment freeswitch -n ai-receptionist -p '{
     "spec": {
       "template": {
         "spec": {
           "containers": [{
             "name": "freeswitch",
             "resources": {
               "requests": {"cpu": "1000m", "memory": "2Gi"},
               "limits": {"cpu": "2000m", "memory": "4Gi"}
             }
           }]
         }
       }
     }
   }'
   ```

2. **Configuration errors:**
   ```bash
   # Check configuration syntax
   kubectl exec -it deployment/freeswitch -n ai-receptionist -- \
     /usr/bin/freeswitch -syntax
   
   # Fix configuration and restart
   kubectl edit configmap freeswitch-config -n ai-receptionist
   kubectl rollout restart deployment/freeswitch -n ai-receptionist
   ```

## AI Engine Issues

### OpenAI API Errors

**Symptoms:**
- AI responses failing
- "API key invalid" errors
- Timeout connecting to OpenAI

**Diagnostics:**
```bash
# Check AI engine logs
kubectl logs -f deployment/ai-engine -n ai-receptionist

# Verify secrets
kubectl get secret ai-engine-secrets -n ai-receptionist -o yaml

# Test API connectivity
kubectl exec -it deployment/ai-engine -n ai-receptionist -- \
  curl -H "Authorization: Bearer YOUR_API_KEY" \
  https://api.openai.com/v1/models
```

**Solutions:**

1. **Invalid API key:**
   ```bash
   # Update secret with correct API key
   kubectl patch secret ai-engine-secrets -n ai-receptionist \
     --type='json' -p='[{
       "op": "replace",
       "path": "/data/openai-api-key",
       "value": "'$(echo -n "YOUR_NEW_API_KEY" | base64)'"
     }]'
   
   # Restart deployment to pick up new secret
   kubectl rollout restart deployment/ai-engine -n ai-receptionist
   ```

2. **Network connectivity issues:**
   ```bash
   # Test external connectivity from pod
   kubectl exec -it deployment/ai-engine -n ai-receptionist -- \
     curl -v https://api.openai.com/v1/models
   
   # Check DNS resolution
   kubectl exec -it deployment/ai-engine -n ai-receptionist -- \
     nslookup api.openai.com
   ```

3. **Rate limiting:**
   ```bash
   # Check for rate limit errors in logs
   kubectl logs deployment/ai-engine -n ai-receptionist | grep -i "rate"
   
   # Consider implementing retry logic or upgrading OpenAI plan
   ```

### AI Engine Performance Issues

**Symptoms:**
- Slow response times
- High CPU/memory usage
- Pods not scaling up

**Diagnostics:**
```bash
# Check resource usage
kubectl top pods -l app=ai-engine -n ai-receptionist

# Check HPA status
kubectl get hpa -n ai-receptionist
kubectl describe hpa ai-engine-hpa -n ai-receptionist

# View metrics
kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/ai-receptionist/pods
```

**Solutions:**

1. **Scaling issues:**
   ```bash
   # Manually scale up for immediate relief
   kubectl scale deployment ai-engine --replicas=5 -n ai-receptionist
   
   # Check HPA configuration
   kubectl edit hpa ai-engine-hpa -n ai-receptionist
   
   # Ensure metrics server is running
   kubectl get deployment metrics-server -n kube-system
   ```

2. **Resource constraints:**
   ```bash
   # Increase resource limits
   kubectl patch deployment ai-engine -n ai-receptionist -p '{
     "spec": {
       "template": {
         "spec": {
           "containers": [{
             "name": "ai-engine",
             "resources": {
               "requests": {"cpu": "1000m", "memory": "2Gi"},
               "limits": {"cpu": "4000m", "memory": "8Gi"}
             }
           }]
         }
       }
     }
   }'
   ```

## Database Issues

### MySQL Connection Problems

**Symptoms:**
- Backend API can't connect to database
- "Connection refused" errors
- Database queries timing out

**Diagnostics:**
```bash
# Check MySQL pod status
kubectl get pods -l app=mysql -n ai-receptionist

# View MySQL logs
kubectl logs -f statefulset/mysql -n ai-receptionist

# Test database connectivity
kubectl exec -it deployment/backend-api -n ai-receptionist -- \
  bundle exec rails runner "puts ActiveRecord::Base.connection.active?"
```

**Solutions:**

1. **MySQL pod not ready:**
   ```bash
   # Check pod events
   kubectl describe pod mysql-0 -n ai-receptionist
   
   # Check persistent volume
   kubectl get pvc -n ai-receptionist
   kubectl describe pvc mysql-storage-mysql-0 -n ai-receptionist
   
   # Restart MySQL if needed
   kubectl delete pod mysql-0 -n ai-receptionist
   ```

2. **Wrong credentials:**
   ```bash
   # Check secrets
   kubectl get secret mysql-secrets -n ai-receptionist -o yaml
   
   # Update if needed
   kubectl patch secret mysql-secrets -n ai-receptionist \
     --type='json' -p='[{
       "op": "replace",
       "path": "/data/mysql-password",
       "value": "'$(echo -n "YOUR_PASSWORD" | base64)'"
     }]'
   ```

3. **Database not initialized:**
   ```bash
   # Run database migrations manually
   kubectl exec -it deployment/backend-api -n ai-receptionist -- \
     bundle exec rails db:create db:migrate db:seed
   ```

### MySQL Performance Issues

**Symptoms:**
- Slow query performance
- High CPU/memory usage
- Connection pool exhaustion

**Diagnostics:**
```bash
# Check MySQL resource usage
kubectl top pod mysql-0 -n ai-receptionist

# Connect to MySQL and check status
kubectl exec -it mysql-0 -n ai-receptionist -- \
  mysql -u root -p -e "SHOW PROCESSLIST; SHOW ENGINE INNODB STATUS;"

# Check slow query log
kubectl exec -it mysql-0 -n ai-receptionist -- \
  tail -f /var/log/mysql/slow.log
```

**Solutions:**

1. **Tune MySQL configuration:**
   ```bash
   # Edit MySQL config
   kubectl edit configmap mysql-config -n ai-receptionist
   
   # Add performance tuning:
   # innodb_buffer_pool_size = 70% of available RAM
   # max_connections = appropriate for workload
   # query_cache_size = 64M
   
   # Restart MySQL
   kubectl delete pod mysql-0 -n ai-receptionist
   ```

2. **Scale resources:**
   ```bash
   # Increase MySQL resources
   kubectl patch statefulset mysql -n ai-receptionist -p '{
     "spec": {
       "template": {
         "spec": {
           "containers": [{
             "name": "mysql",
             "resources": {
               "requests": {"cpu": "1000m", "memory": "4Gi"},
               "limits": {"cpu": "2000m", "memory": "8Gi"}
             }
           }]
         }
       }
     }
   }'
   ```

## Backend API Issues

### Application Errors

**Symptoms:**
- 500 Internal Server Error
- API endpoints not responding
- Ruby/Rails errors in logs

**Diagnostics:**
```bash
# Check backend API logs
kubectl logs -f deployment/backend-api -n ai-receptionist

# Check pod status
kubectl get pods -l app=backend-api -n ai-receptionist

# Test API endpoints
kubectl exec -it deployment/backend-api -n ai-receptionist -- \
  curl -H "Content-Type: application/json" \
  http://localhost:3000/api/v1/customers
```

**Solutions:**

1. **Application startup issues:**
   ```bash
   # Check environment variables
   kubectl exec -it deployment/backend-api -n ai-receptionist -- env
   
   # Check database connection
   kubectl exec -it deployment/backend-api -n ai-receptionist -- \
     bundle exec rails console -e production
   ```

2. **Missing gems or dependencies:**
   ```bash
   # Rebuild image with updated dependencies
   docker build -t ai-receptionist/backend:latest ./backend-ai-receptionist/
   kubectl set image deployment/backend-api backend-api=ai-receptionist/backend:latest -n ai-receptionist
   ```

### Rails Console Access

**Debugging Rails application:**
```bash
# Access Rails console
kubectl exec -it deployment/backend-api -n ai-receptionist -- \
  bundle exec rails console -e production

# Check database records
> Customer.count
> PhoneNumber.includes(:customer).limit(5)
> CallTranscript.last

# Test API internally
> app.get '/api/v1/customers'
> puts app.response.body
```

## Networking Issues

### Ingress Problems

**Symptoms:**
- Can't access APIs via HTTPS
- SSL certificate errors
- 404 errors for valid endpoints

**Diagnostics:**
```bash
# Check ingress status
kubectl get ingress -n ai-receptionist
kubectl describe ingress ai-receptionist-ingress -n ai-receptionist

# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -f deployment/ingress-nginx-controller -n ingress-nginx
```

**Solutions:**

1. **Ingress controller not installed:**
   ```bash
   # Install NGINX Ingress Controller
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
   
   # Wait for controller to be ready
   kubectl wait --namespace ingress-nginx \
     --for=condition=ready pod \
     --selector=app.kubernetes.io/component=controller \
     --timeout=120s
   ```

2. **SSL certificate issues:**
   ```bash
   # Check TLS secret
   kubectl get secret tls-secret -n ai-receptionist
   
   # Generate self-signed cert for testing
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout tls.key -out tls.crt -subj "/CN=ai-receptionist.local"
   
   kubectl create secret tls tls-secret \
     --key tls.key --cert tls.crt -n ai-receptionist
   ```

### Service Discovery Issues

**Symptoms:**
- Services can't find each other
- DNS resolution failing
- Connection refused between services

**Diagnostics:**
```bash
# Test DNS resolution
kubectl exec -it deployment/backend-api -n ai-receptionist -- \
  nslookup mysql.ai-receptionist.svc.cluster.local

# Check service endpoints
kubectl get endpoints -n ai-receptionist

# Test service connectivity
kubectl exec -it deployment/backend-api -n ai-receptionist -- \
  telnet mysql 3306
```

**Solutions:**

1. **DNS issues:**
   ```bash
   # Check CoreDNS
   kubectl get pods -n kube-system -l k8s-app=kube-dns
   
   # Restart CoreDNS if needed
   kubectl rollout restart deployment/coredns -n kube-system
   ```

2. **Network policy blocking:**
   ```bash
   # Check network policies
   kubectl get networkpolicy -n ai-receptionist
   
   # Temporarily remove for testing
   kubectl delete networkpolicy ai-receptionist-network-policy -n ai-receptionist
   ```

## Resource and Performance Issues

### Out of Resources

**Symptoms:**
- Pods stuck in "Pending" state
- "Insufficient cpu/memory" events
- Nodes at capacity

**Diagnostics:**
```bash
# Check node resources
kubectl top nodes
kubectl describe nodes

# Check pod resource requests
kubectl get pods -n ai-receptionist -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources.requests}{"\n"}{end}'

# Check events for scheduling issues
kubectl get events -n ai-receptionist --sort-by='.lastTimestamp' | grep -i "insufficient\|pending"
```

**Solutions:**

1. **Scale cluster:**
   ```bash
   # Add more nodes (cloud provider specific)
   # For EKS:
   eksctl scale nodegroup --cluster=my-cluster --name=my-nodegroup --nodes=5
   
   # For GKE:
   gcloud container clusters resize my-cluster --num-nodes=5
   ```

2. **Optimize resource requests:**
   ```bash
   # Reduce resource requests for non-critical services
   kubectl patch deployment ai-engine -n ai-receptionist -p '{
     "spec": {
       "template": {
         "spec": {
           "containers": [{
             "name": "ai-engine",
             "resources": {
               "requests": {"cpu": "500m", "memory": "1Gi"}
             }
           }]
         }
       }
     }
   }'
   ```

### Storage Issues

**Symptoms:**
- PVCs stuck in "Pending"
- Database pods failing to start
- "No storage class" errors

**Diagnostics:**
```bash
# Check PVC status
kubectl get pvc -n ai-receptionist
kubectl describe pvc mysql-storage-mysql-0 -n ai-receptionist

# Check storage classes
kubectl get storageclass

# Check persistent volumes
kubectl get pv
```

**Solutions:**

1. **No default storage class:**
   ```bash
   # Set default storage class
   kubectl patch storageclass YOUR_STORAGE_CLASS -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
   
   # Or specify in PVC
   kubectl patch pvc mysql-storage-mysql-0 -n ai-receptionist -p '{"spec": {"storageClassName": "YOUR_STORAGE_CLASS"}}'
   ```

2. **Insufficient storage:**
   ```bash
   # Check available storage
   kubectl get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,STATUS:.status.phase
   
   # Clean up unused PVs if needed
   kubectl delete pv UNUSED_PV_NAME
   ```

## Monitoring and Logging

### Missing Metrics

**Symptoms:**
- HPA not working due to missing metrics
- No resource usage data
- Monitoring dashboards empty

**Solutions:**

1. **Install metrics server:**
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   
   # Wait for metrics to be available
   kubectl get apiservice v1beta1.metrics.k8s.io -o yaml
   ```

2. **Check metrics server:**
   ```bash
   kubectl get pods -n kube-system -l k8s-app=metrics-server
   kubectl logs -f deployment/metrics-server -n kube-system
   ```

### Log Collection Issues

**Symptoms:**
- Logs not appearing in central system
- Log shipping failures
- Missing application logs

**Solutions:**

1. **Check pod logs directly:**
   ```bash
   # View all logs from a deployment
   kubectl logs deployment/freeswitch -n ai-receptionist --all-containers=true --since=1h
   
   # Stream logs in real-time
   kubectl logs -f deployment/ai-engine -n ai-receptionist
   ```

2. **Install logging solution:**
   ```bash
   # Install Loki for log aggregation
   helm repo add grafana https://grafana.github.io/helm-charts
   helm install loki grafana/loki-stack -n monitoring --create-namespace
   ```

## Emergency Procedures

### Complete System Recovery

If the entire system is down:

1. **Check cluster health:**
   ```bash
   kubectl get nodes
   kubectl get pods -A | grep -v Running
   ```

2. **Restart critical services:**
   ```bash
   # Restart in dependency order
   kubectl rollout restart statefulset/mysql -n ai-receptionist
   kubectl rollout restart deployment/redis -n ai-receptionist
   kubectl rollout restart deployment/backend-api -n ai-receptionist
   kubectl rollout restart deployment/ai-engine -n ai-receptionist
   kubectl rollout restart deployment/freeswitch -n ai-receptionist
   ```

3. **Verify each service before proceeding:**
   ```bash
   kubectl rollout status statefulset/mysql -n ai-receptionist
   kubectl rollout status deployment/backend-api -n ai-receptionist
   # etc...
   ```

### Data Recovery

If database corruption occurs:

1. **Stop all services:**
   ```bash
   kubectl scale deployment --all --replicas=0 -n ai-receptionist
   ```

2. **Restore from backup:**
   ```bash
   # Access MySQL pod
   kubectl exec -it mysql-0 -n ai-receptionist -- bash
   
   # Restore database
   mysql -u root -p ai_receptionist_production < /backup/latest-backup.sql
   ```

3. **Restart services:**
   ```bash
   kubectl scale statefulset mysql --replicas=1 -n ai-receptionist
   kubectl rollout status statefulset/mysql -n ai-receptionist
   
   kubectl scale deployment backend-api --replicas=3 -n ai-receptionist
   # ... restart other services
   ```

### Contact Information

For additional support:
- **Documentation**: See `KUBERNETES-DEPLOYMENT.md` for detailed setup
- **Issue Tracking**: GitHub Issues in the project repository
- **Emergency Contact**: Define your escalation procedure

Remember to document any issues and solutions you discover for future reference.