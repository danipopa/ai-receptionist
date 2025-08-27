# AI Receptionist Setup Guide

This guide will walk you through setting up the complete AI Receptionist platform step by step.

## Prerequisites

Before starting, ensure you have the following installed:

- Docker & Docker Compose
- Git
- Node.js 18+ (for local development)
- Python 3.9+ (for local development)

## Step 1: Clone and Initial Setup

```bash
git clone <your-repository-url>
cd AI-Receptionist

# Copy environment configuration
cp .env.example .env

# Edit .env file with your specific configuration
nano .env
```

## Step 2: Environment Configuration

Edit the `.env` file with your settings:

```bash
# Database
DATABASE_URL=postgresql://postgres:postgres123@localhost:5432/ai_receptionist

# API Keys (if using external services)
OPENAI_API_KEY=your_openai_key_here  # Optional fallback
TWILIO_ACCOUNT_SID=your_twilio_sid   # For phone number provisioning
TWILIO_AUTH_TOKEN=your_twilio_token

# Domain configuration
DOMAIN=your-domain.com
SSL_EMAIL=your-email@domain.com

# SIP Provider Configuration
SIP_PROVIDER_HOST=sip.yourprovider.com
SIP_USERNAME=your_sip_username
SIP_PASSWORD=your_sip_password
```

## Step 3: Build and Start Services

### Option A: Full Docker Setup (Recommended)

```bash
# Build all services
docker-compose -f deployment/docker-compose.yml build

# Start the platform
docker-compose -f deployment/docker-compose.yml up -d

# Check service health
docker-compose -f deployment/docker-compose.yml ps
```

### Option B: Development Setup

```bash
# Start core services only
docker-compose -f deployment/docker-compose.yml up -d postgres redis ollama

# Install and run backend
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Install and run frontend (new terminal)
cd frontend
npm install
npm start

# Setup Rasa (new terminal)
cd ai-engine/rasa
pip install rasa
rasa train
rasa run --enable-api --cors "*" --port 5005
```

## Step 4: Download AI Models

### Whisper Model
```bash
# Create models directory
mkdir -p backend/models

# Download Whisper model
cd backend/models
curl -L -o ggml-base.en.bin \
  "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
```

### Ollama Models
```bash
# Pull LLaMA-3 model (this may take several minutes)
docker exec -it ai-receptionist_ollama_1 ollama pull llama3

# Or for a smaller model for testing:
docker exec -it ai-receptionist_ollama_1 ollama pull llama3:8b
```

### TTS Models
```bash
# Coqui TTS models will be downloaded automatically on first use
# Or pre-download specific models:
python -c "
from TTS.api import TTS
tts = TTS(model_name='tts_models/en/ljspeech/tacotron2-DDC')
print('Model downloaded successfully')
"
```

## Step 5: Asterisk Configuration

### Configure SIP Trunk
Edit `telephony/asterisk/sip.conf`:

```ini
[sip-provider](trunk-template)
username=YOUR_SIP_USERNAME
secret=YOUR_SIP_PASSWORD
host=YOUR_SIP_PROVIDER
fromdomain=YOUR_SIP_DOMAIN
context=ai-receptionist
```

### Test Asterisk Connection
```bash
# Connect to Asterisk CLI
docker exec -it ai-receptionist_asterisk_1 asterisk -rvvv

# Check SIP registration
sip show registry

# Test dial plan
dialplan show ai-receptionist
```

## Step 6: Create Your First Business

### Using the Web Interface
1. Open http://localhost:3000
2. Navigate to "Businesses"
3. Click "Add New Business"
4. Fill in:
   - Business Name
   - Phone Number
   - Welcome Message
   - Voice Configuration

### Using API
```bash
curl -X POST http://localhost:8000/businesses \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Business",
    "phone_number": "+1234567890",
    "welcome_message": "Hello! Thank you for calling Test Business. How can I help you?",
    "voice_config": {
      "engine": "coqui",
      "model_name": "tts_models/en/ljspeech/tacotron2-DDC",
      "speed": 1.0
    }
  }'
```

## Step 7: Test the System

### Test Call Flow
1. Configure a test SIP phone (like Zoiper) with credentials:
   - Username: 1001
   - Password: testpass123
   - Server: localhost:5060

2. Call your business number
3. Verify the AI receptionist answers
4. Check the dashboard for call activity

### Test API Endpoints
```bash
# Health check
curl http://localhost:8000/health

# List businesses
curl http://localhost:8000/businesses

# Test TTS
curl -X POST http://localhost:8000/tts/test \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello, this is a test", "voice_config": {"engine": "coqui"}}'
```

## Step 8: Production Deployment

### SSL Configuration
1. Update `deployment/nginx/nginx.conf` with your domain
2. Configure SSL certificates:

```bash
# Using Let's Encrypt
docker run --rm -v $(pwd)/deployment/nginx/ssl:/etc/letsencrypt \
  certbot/certbot certonly --standalone \
  -d your-domain.com \
  --email your-email@domain.com \
  --agree-tos
```

### Environment Security
1. Change default passwords in `.env`
2. Configure firewall rules
3. Set up monitoring and backups

### Scaling
```bash
# Scale specific services
docker-compose -f deployment/docker-compose.yml up -d --scale backend=3

# Or use Kubernetes deployment
kubectl apply -f deployment/kubernetes/
```

## Troubleshooting

### Common Issues

1. **Whisper not working**: Check model path and permissions
   ```bash
   ls -la backend/models/
   ```

2. **Ollama connection failed**: Ensure model is downloaded
   ```bash
   docker logs ai-receptionist_ollama_1
   ```

3. **Asterisk can't connect**: Check network configuration
   ```bash
   docker exec -it ai-receptionist_asterisk_1 netstat -tlnp
   ```

4. **TTS errors**: Install TTS dependencies
   ```bash
   pip install TTS[all]
   ```

### Logs
```bash
# Backend logs
docker logs ai-receptionist_backend_1

# Asterisk logs
docker logs ai-receptionist_asterisk_1

# Database logs
docker logs ai-receptionist_postgres_1
```

## Next Steps

1. Configure additional businesses
2. Set up phone number routing
3. Customize conversation flows in Rasa
4. Configure calendar integrations
5. Set up monitoring and analytics

## Support

For issues and questions:
- Check the troubleshooting section
- Review logs for error messages
- Open an issue on GitHub
- Consult the API documentation at http://localhost:8000/docs
