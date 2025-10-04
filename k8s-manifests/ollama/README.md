# Ollama AI Engine for AI Receptionist

This directory contains Kubernetes manifests for deploying Ollama, a local LLM runtime.

## Architecture

Ollama provides a local AI inference engine that runs large language models (LLMs) without external API dependencies. It's designed for:
- **Privacy**: All data stays within your infrastructure
- **Cost-effective**: No per-request API charges
- **Low latency**: Local inference without network round-trips
- **Offline capability**: Works without internet connectivity

## Components

### 1. Persistent Storage (`pvc.yaml`)
- **ollama-models-pvc**: 50Gi for storing LLM model files
- **ollama-data-pvc**: 10Gi for logs and temporary data

### 2. Deployment (`deployment.yaml`)
- Runs Ollama container (CPU or GPU)
- Configurable resource limits (4-16Gi RAM)
- Health checks and probes
- Persistent model storage

### 3. Services (`service.yaml`)
- **ollama**: ClusterIP for internal access (port 11434)
- **ollama-external**: NodePort for external access (port 30434)

### 4. Model Initialization (`init-models-job.yaml`)
- Kubernetes Job to pre-download models
- Default: llama3.2:3b (fast, 2GB)
- Optional: mistral, llama2, neural-chat, phi

## Deployment Steps

### 1. Deploy Ollama
```bash
# Apply all manifests
kubectl apply -f k8s-manifests/ollama/

# Watch deployment
kubectl get pods -n ai-receptionist -l app=ollama -w

# Check logs
kubectl logs -n ai-receptionist -l app=ollama
```

### 2. Initialize Models
```bash
# Run the model initialization job
kubectl apply -f k8s-manifests/ollama/init-models-job.yaml

# Monitor the job (will take 10-30 minutes depending on models)
kubectl logs -n ai-receptionist -f job/ollama-init-models

# Check job status
kubectl get jobs -n ai-receptionist
```

### 3. Verify Installation
```bash
# Test Ollama API from within cluster
kubectl run -it --rm test --image=curlimages/curl --restart=Never -- \
  curl -s http://ollama.ai-receptionist.svc.cluster.local:11434/api/tags

# Or test from node (if using NodePort)
curl http://localhost:30434/api/tags
```

### 4. Test a Model
```bash
# Generate a response
kubectl run -it --rm test --image=curlimages/curl --restart=Never -- \
  curl -X POST http://ollama.ai-receptionist.svc.cluster.local:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2:3b",
    "prompt": "Why is the sky blue?",
    "stream": false
  }'
```

## Model Selection

### Recommended Models for AI Receptionist

| Model | Size | Speed | Quality | Use Case |
|-------|------|-------|---------|----------|
| **llama3.2:3b** | 2GB | ⚡⚡⚡ | ⭐⭐⭐ | Default - Fast responses, good quality |
| **mistral:7b** | 4GB | ⚡⚡ | ⭐⭐⭐⭐ | Balanced - Better reasoning |
| **llama2:7b** | 4GB | ⚡⚡ | ⭐⭐⭐ | General purpose, stable |
| **neural-chat:7b** | 4GB | ⚡⚡ | ⭐⭐⭐⭐ | Optimized for conversations |
| **phi:2.7b** | 1.6GB | ⚡⚡⚡ | ⭐⭐ | Ultra-fast, simple tasks |

### Pull Additional Models
```bash
# Access Ollama pod
kubectl exec -it -n ai-receptionist deployment/ollama -- bash

# Pull a model manually
ollama pull mistral:7b
ollama pull llama2:7b
ollama pull codellama:7b

# List available models
ollama list
```

## Resource Requirements

### Minimum (for 3B models)
- CPU: 2 cores
- RAM: 4GB
- Storage: 10GB

### Recommended (for 7B models)
- CPU: 4 cores
- RAM: 8GB
- Storage: 30GB

### Optimal (for multiple 7B models)
- CPU: 8 cores
- RAM: 16GB
- Storage: 50GB
- GPU: NVIDIA GPU with 8GB VRAM (optional, for faster inference)

## GPU Support

To enable GPU acceleration (10-100x faster):

### 1. Install NVIDIA GPU Operator
```bash
# Add NVIDIA Helm repo
helm repo add nvidia https://nvidia.github.io/gpu-operator
helm repo update

# Install GPU operator
helm install --wait --generate-name \
  -n gpu-operator --create-namespace \
  nvidia/gpu-operator
```

### 2. Update Deployment
Uncomment GPU-related sections in `deployment.yaml`:
```yaml
env:
  - name: OLLAMA_NUM_GPU
    value: "1"
  - name: OLLAMA_GPU_LAYERS
    value: "35"

resources:
  limits:
    nvidia.com/gpu: "1"
```

### 3. Redeploy
```bash
kubectl apply -f k8s-manifests/ollama/deployment.yaml
kubectl rollout restart deployment/ollama -n ai-receptionist
```

## API Integration

### Backend Service Connection

The `backend-ai-receptionist` service will connect to Ollama at:
```
http://ollama.ai-receptionist.svc.cluster.local:11434
```

### Example API Calls

#### Generate Text
```bash
curl http://ollama:11434/api/generate \
  -d '{
    "model": "llama3.2:3b",
    "prompt": "Hello, how can I help you today?",
    "stream": false
  }'
```

#### Chat Completion
```bash
curl http://ollama:11434/api/chat \
  -d '{
    "model": "llama3.2:3b",
    "messages": [
      {"role": "system", "content": "You are a helpful receptionist."},
      {"role": "user", "content": "What are your hours?"}
    ],
    "stream": false
  }'
```

#### Embeddings (for semantic search)
```bash
curl http://ollama:11434/api/embeddings \
  -d '{
    "model": "llama3.2:3b",
    "prompt": "Convert this text to embeddings"
  }'
```

## Monitoring

### Check Model Status
```bash
kubectl exec -it -n ai-receptionist deployment/ollama -- ollama list
```

### View Logs
```bash
kubectl logs -n ai-receptionist -l app=ollama --tail=100 -f
```

### Check Resource Usage
```bash
kubectl top pod -n ai-receptionist -l app=ollama
```

### Test Model Performance
```bash
time kubectl exec -it -n ai-receptionist deployment/ollama -- \
  ollama run llama3.2:3b "What is 2+2?"
```

## Troubleshooting

### Pod Won't Start
```bash
# Check pod status
kubectl describe pod -n ai-receptionist -l app=ollama

# Check PVC binding
kubectl get pvc -n ai-receptionist

# Check resource availability
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### Model Download Fails
```bash
# Check init job logs
kubectl logs -n ai-receptionist job/ollama-init-models

# Manually pull model
kubectl exec -it -n ai-receptionist deployment/ollama -- ollama pull llama3.2:3b
```

### Out of Memory
```bash
# Increase memory limits in deployment.yaml
resources:
  limits:
    memory: "24Gi"  # For larger models

# Or use smaller models
ollama pull phi:2.7b
```

### Slow Inference
- Consider using GPU acceleration
- Use smaller models (3B instead of 7B)
- Reduce concurrent requests
- Increase CPU allocation

## Scaling

Ollama deployment is configured with `replicas: 1` because:
- Models are large and memory-intensive
- Shared storage for models
- Use a load balancer if multiple replicas needed

For high availability:
1. Use multiple nodes with local model copies
2. Deploy multiple instances with node affinity
3. Use external load balancer

## Security

### Network Policies
```bash
# Restrict access to Ollama (optional)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ollama-access
  namespace: ai-receptionist
spec:
  podSelector:
    matchLabels:
      app: ollama
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend-ai-receptionist
    - podSelector:
        matchLabels:
          app: ai-engine
    ports:
    - protocol: TCP
      port: 11434
EOF
```

### Model Security
- Models are stored in persistent volumes
- Regular backups recommended
- Use RBAC to limit access to Ollama pods

## Next Steps

1. ✅ Deploy Ollama
2. ✅ Initialize models
3. 🔄 Update backend service to use Ollama
4. 🔄 Test end-to-end AI conversations
5. 🔄 Optimize model selection for your use case
6. 🔄 Monitor performance and adjust resources

## References

- [Ollama Documentation](https://github.com/ollama/ollama)
- [Ollama API Reference](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Available Models](https://ollama.ai/library)
- [Model Cards](https://huggingface.co/models)
