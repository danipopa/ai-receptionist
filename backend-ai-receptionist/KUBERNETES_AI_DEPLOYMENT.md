# Kubernetes AI Service Deployment Guide

This guide shows how to deploy AI services in your Kubernetes cluster that your Ruby API can consume.

## Option 1: Ollama in Kubernetes (Recommended for Privacy)

### Ollama Deployment

```yaml
# ollama-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
  namespace: ai-services
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
    spec:
      containers:
      - name: ollama
        image: ollama/ollama:latest
        ports:
        - containerPort: 11434
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "8Gi"
            cpu: "4000m"
        volumeMounts:
        - name: ollama-data
          mountPath: /root/.ollama
        env:
        - name: OLLAMA_HOST
          value: "0.0.0.0"
      volumes:
      - name: ollama-data
        persistentVolumeClaim:
          claimName: ollama-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: ollama-service
  namespace: ai-services
spec:
  selector:
    app: ollama
  ports:
  - port: 11434
    targetPort: 11434
  type: ClusterIP
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ollama-pvc
  namespace: ai-services
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```

### Model Download Job

```yaml
# ollama-model-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: ollama-pull-models
  namespace: ai-services
spec:
  template:
    spec:
      containers:
      - name: model-puller
        image: ollama/ollama:latest
        command: 
        - /bin/bash
        - -c
        - |
          # Wait for Ollama service to be ready
          until curl -f http://ollama-service:11434/api/tags; do
            echo "Waiting for Ollama service..."
            sleep 5
          done
          
          # Pull required models
          ollama pull llama2:7b
          ollama pull codellama:7b
          ollama pull mistral:7b
        env:
        - name: OLLAMA_HOST
          value: "http://ollama-service:11434"
      restartPolicy: OnFailure
```

## Option 2: Hugging Face Transformers Service

### Custom HF Transformers API

```dockerfile
# Dockerfile.hf-transformers
FROM python:3.9-slim

WORKDIR /app

RUN pip install torch transformers accelerate flask gunicorn

COPY hf-api.py .

EXPOSE 8080

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "1", "--timeout", "120", "hf-api:app"]
```

```python
# hf-api.py
from flask import Flask, request, jsonify
from transformers import pipeline, AutoTokenizer, AutoModelForCausalLM
import torch
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# Initialize models
try:
    # Text generation
    text_generator = pipeline(
        "text-generation",
        model="microsoft/DialoGPT-medium",
        tokenizer="microsoft/DialoGPT-medium",
        device=0 if torch.cuda.is_available() else -1
    )
    
    # Speech recognition (Whisper)
    speech_recognizer = pipeline(
        "automatic-speech-recognition",
        model="openai/whisper-small",
        device=0 if torch.cuda.is_available() else -1
    )
    
    app.logger.info("Models loaded successfully")
except Exception as e:
    app.logger.error(f"Failed to load models: {e}")

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy"})

@app.route('/generate', methods=['POST'])
def generate_text():
    try:
        data = request.json
        prompt = data.get('prompt', '')
        max_length = data.get('max_length', 150)
        
        response = text_generator(
            prompt,
            max_length=max_length,
            temperature=0.7,
            do_sample=True,
            pad_token_id=text_generator.tokenizer.eos_token_id
        )
        
        return jsonify({
            "text": response[0]['generated_text'],
            "model": "microsoft/DialoGPT-medium"
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/transcribe', methods=['POST'])
def transcribe_audio():
    try:
        # Handle audio file upload
        if 'audio' not in request.files:
            return jsonify({"error": "No audio file provided"}), 400
            
        audio_file = request.files['audio']
        result = speech_recognizer(audio_file)
        
        return jsonify({
            "transcript": result['text'],
            "model": "openai/whisper-small"
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

### HF Transformers Kubernetes Deployment

```yaml
# hf-transformers-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hf-transformers
  namespace: ai-services
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hf-transformers
  template:
    metadata:
      labels:
        app: hf-transformers
    spec:
      containers:
      - name: hf-transformers
        image: your-registry/hf-transformers:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "4Gi"
            cpu: "2000m"
          limits:
            memory: "12Gi"
            cpu: "6000m"
        env:
        - name: TRANSFORMERS_CACHE
          value: "/app/cache"
        volumeMounts:
        - name: model-cache
          mountPath: /app/cache
      volumes:
      - name: model-cache
        persistentVolumeClaim:
          claimName: hf-cache-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: hf-transformers-service
  namespace: ai-services
spec:
  selector:
    app: hf-transformers
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
```

## Option 3: External API Configuration

For Google Gemini or Hugging Face API, you don't need Kubernetes deployments - just configure your Ruby app:

```yaml
# Ruby API deployment with external AI services
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-receptionist-api
spec:
  template:
    spec:
      containers:
      - name: api
        image: your-registry/ai-receptionist:latest
        env:
        # Use external APIs
        - name: AI_PROVIDER
          value: "gemini"  # or "huggingface"
        - name: GOOGLE_API_KEY
          valueFrom:
            secretKeyRef:
              name: ai-secrets
              key: google-api-key
        - name: HUGGINGFACE_API_KEY
          valueFrom:
            secretKeyRef:
              name: ai-secrets
              key: hf-api-key
```

## What Should You Deploy?

**For your Kubernetes cluster, I recommend:**

1. **Deploy Ollama** (Option 1) for complete privacy and control
2. **Keep the Ruby API changes we made** as they allow you to switch between providers
3. **Use external APIs** (Gemini/HF) as backup options

## Updated Ruby API Configuration

Your Ruby API should point to the Kubernetes services:

```bash
# For Ollama in Kubernetes
AI_PROVIDER=ollama
OLLAMA_URL=http://ollama-service.ai-services.svc.cluster.local:11434

# For HF Transformers in Kubernetes  
AI_PROVIDER=huggingface
HUGGINGFACE_API_URL=http://hf-transformers-service.ai-services.svc.cluster.local:8080

# For external APIs
AI_PROVIDER=gemini
GOOGLE_API_KEY=your_api_key
```

Would you like me to create the complete Kubernetes manifests for deploying these AI services in your cluster?