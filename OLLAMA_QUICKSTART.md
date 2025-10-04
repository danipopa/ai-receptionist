# Quick Start: Deploy Ollama AI Engine

This guide will help you deploy Ollama on your Kubernetes cluster in ~15 minutes.

## Prerequisites

- Kubernetes cluster running
- kubectl configured
- At least 8GB RAM available on a node
- 50GB storage available

## Step 1: Deploy Ollama (5 minutes)

```bash
cd ~/Develop/ai-receptionist

# Apply all Ollama manifests
kubectl apply -f k8s-manifests/ollama/namespace.yaml
kubectl apply -f k8s-manifests/ollama/pvc.yaml
kubectl apply -f k8s-manifests/ollama/deployment.yaml
kubectl apply -f k8s-manifests/ollama/service.yaml

# Watch deployment
kubectl get pods -n ai-receptionist -l app=ollama -w
```

Wait until the pod status shows `Running`.

## Step 2: Download AI Models (10-15 minutes)

This will download the llama3.2:3b model (~2GB):

```bash
# Start the model initialization job
kubectl apply -f k8s-manifests/ollama/init-models-job.yaml

# Monitor the download progress
kubectl logs -n ai-receptionist -f job/ollama-init-models

# You'll see output like:
# Pulling model: llama3.2:3b
# This may take several minutes...
# ✓ Successfully pulled llama3.2:3b
```

## Step 3: Verify Installation

```bash
# Check if Ollama is healthy
kubectl exec -it -n ai-receptionist deployment/ollama -- ollama list

# Expected output:
# NAME              ID              SIZE      MODIFIED
# llama3.2:3b       abc123def       2.0 GB    2 minutes ago

# Test the model
kubectl exec -it -n ai-receptionist deployment/ollama -- \
  ollama run llama3.2:3b "Hello, how are you?"
```

## Step 4: Update Backend Configuration

```bash
# Apply the backend configuration to use Ollama
kubectl apply -f k8s-manifests/ollama/backend-config.yaml

# Update backend deployment to use the config
kubectl set env deployment/backend-ai-receptionist -n ai-receptionist \
  --from=configmap/backend-ai-config

# Restart backend to pick up changes
kubectl rollout restart deployment/backend-ai-receptionist -n ai-receptionist

# Watch the restart
kubectl get pods -n ai-receptionist -l app=backend-ai-receptionist -w
```

## Step 5: Test End-to-End

```bash
# Test from backend
kubectl exec -it -n ai-receptionist deployment/backend-ai-receptionist -- \
  curl -X POST http://ollama:11434/api/chat \
  -d '{
    "model": "llama3.2:3b",
    "messages": [
      {"role": "system", "content": "You are a helpful receptionist."},
      {"role": "user", "content": "What are your hours?"}
    ],
    "stream": false
  }'
```

## Troubleshooting

### Pod Won't Start
```bash
# Check pod status
kubectl describe pod -n ai-receptionist -l app=ollama

# Common issues:
# - Not enough memory: Scale down other pods or increase node resources
# - PVC not bound: Check storage class and available storage
```

### Model Download Fails
```bash
# Check job logs
kubectl logs -n ai-receptionist job/ollama-init-models

# If it times out, pull manually:
kubectl exec -it -n ai-receptionist deployment/ollama -- ollama pull llama3.2:3b
```

### Backend Can't Connect
```bash
# Verify Ollama service
kubectl get svc -n ai-receptionist ollama

# Test connectivity from backend pod
kubectl exec -it -n ai-receptionist deployment/backend-ai-receptionist -- \
  curl -v http://ollama:11434/api/tags
```

## Performance Tuning

### Use a Faster Model
For quicker responses, use the smaller phi model:

```bash
kubectl exec -it -n ai-receptionist deployment/ollama -- ollama pull phi:2.7b

# Update backend config
kubectl edit configmap/backend-ai-config -n ai-receptionist
# Change: OLLAMA_TEXT_MODEL: "phi:2.7b"

# Restart backend
kubectl rollout restart deployment/backend-ai-receptionist -n ai-receptionist
```

### Use a Better Model
For higher quality responses, use mistral:

```bash
kubectl exec -it -n ai-receptionist deployment/ollama -- ollama pull mistral:7b

# Update backend config
kubectl edit configmap/backend-ai-config -n ai-receptionist
# Change: OLLAMA_TEXT_MODEL: "mistral:7b"

# Restart backend
kubectl rollout restart deployment/backend-ai-receptionist -n ai-receptionist
```

### Enable GPU (if available)
Edit `k8s-manifests/ollama/deployment.yaml` and uncomment GPU sections, then:

```bash
kubectl apply -f k8s-manifests/ollama/deployment.yaml
```

## Next Steps

1. ✅ Ollama deployed and running
2. ✅ Models downloaded
3. ✅ Backend configured to use Ollama
4. 🔄 Test with a phone call through FreeSWITCH
5. 🔄 Monitor performance and tune model selection
6. 🔄 Add speech-to-text service (Whisper)
7. 🔄 Add text-to-speech service (Coqui TTS)

## Monitoring

```bash
# Watch resource usage
kubectl top pod -n ai-receptionist -l app=ollama

# Check logs
kubectl logs -n ai-receptionist -l app=ollama --tail=100 -f

# View all Ollama resources
kubectl get all -n ai-receptionist -l app=ollama
```

## Cost Savings

Running Ollama locally vs cloud APIs:

- **OpenAI GPT-4**: ~$0.03-0.06 per 1K tokens
- **Ollama llama3.2**: FREE (just server costs)

For 1000 calls/day with ~500 tokens each:
- OpenAI: ~$450-900/month
- Ollama: $0/month (+ server ~$50-200/month)

**Savings: ~$400-700/month** 💰

## Security Notes

- Ollama runs in cluster network (not exposed publicly)
- No data sent to external APIs
- All AI processing stays on your infrastructure
- Consider network policies for additional isolation

## Support

For issues, check:
- [Ollama GitHub](https://github.com/ollama/ollama)
- [Ollama Models](https://ollama.ai/library)
- Project README: `k8s-manifests/ollama/README.md`
