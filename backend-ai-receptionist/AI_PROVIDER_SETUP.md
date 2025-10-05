# AI Provider Configuration

This AI Receptionist backend supports multiple AI providers for flexible deployment options. You can choose between cloud-based services and local inference depending on your needs.

## Available Providers

### 1. Hugging Face Transformers (Free/Open Source)
Uses Hugging Face's inference API with free and open source models.

**Configuration:**
```bash
# Set the AI provider
AI_PROVIDER=huggingface

# Hugging Face API key (free tier available)
HUGGINGFACE_API_KEY=your_hf_api_key_here

# Optional: Custom models (defaults provided)
HF_TEXT_MODEL=microsoft/DialoGPT-medium
HF_SPEECH_MODEL=openai/whisper-large-v3
HF_TTS_MODEL=microsoft/speecht5_tts
```

**Getting Started:**
1. Sign up for a free Hugging Face account at https://huggingface.co/
2. Generate an API token in your Hugging Face settings
3. Set the environment variables above
4. Restart your Rails application

**Features:**
- ✅ Text generation
- ✅ Speech-to-text transcription
- ✅ Text-to-speech synthesis
- ✅ Free tier available
- ❌ May have rate limits on free tier

### 2. Ollama (Run Models Locally)
Run AI models locally on your own hardware using Ollama.

**Configuration:**
```bash
# Set the AI provider
AI_PROVIDER=ollama

# Ollama server URL (default: localhost)
OLLAMA_URL=http://localhost:11434

# Optional: Custom models (defaults provided)
OLLAMA_TEXT_MODEL=llama2
OLLAMA_SPEECH_MODEL=whisper
```

**Getting Started:**
1. Install Ollama from https://ollama.ai/
2. Pull required models:
   ```bash
   ollama pull llama2
   ollama pull whisper  # For speech recognition (if available)
   ```
3. Start Ollama server:
   ```bash
   ollama serve
   ```
4. Set the environment variables above
5. Restart your Rails application

**Features:**
- ✅ Text generation
- ⚠️ Speech-to-text (limited support)
- ❌ Text-to-speech (not supported)
- ✅ Completely local/private
- ✅ No API costs
- ❌ Requires local computing resources

### 3. Google Gemini API (Free Tier Available)
Use Google's Gemini AI models via their API.

**Configuration:**
```bash
# Set the AI provider
AI_PROVIDER=gemini

# Google API key
GOOGLE_API_KEY=your_google_api_key_here

# Optional: Custom model (default: gemini-pro)
GEMINI_MODEL=gemini-pro
```

**Getting Started:**
1. Go to Google AI Studio (https://makersuite.google.com/)
2. Create a new API key
3. Set the environment variables above
4. Restart your Rails application

**Features:**
- ✅ Text generation
- ⚠️ Speech-to-text (requires separate Google Cloud Speech setup)
- ⚠️ Text-to-speech (requires separate Google Cloud TTS setup)
- ✅ Free tier available
- ✅ High-quality responses
- ❌ Requires separate setup for audio features

### 4. Original Implementation (Default)
Use the original custom AI engine implementation.

**Configuration:**
```bash
# Set the AI provider (or leave unset)
AI_PROVIDER=original

# AI Engine URL
AI_ENGINE_URL=http://localhost:8081
```

## Environment Variables Reference

### Required for each provider:

**Hugging Face:**
- `HUGGINGFACE_API_KEY` - Your Hugging Face API token

**Ollama:**
- `OLLAMA_URL` - URL where Ollama is running (default: http://localhost:11434)

**Gemini:**
- `GOOGLE_API_KEY` - Your Google AI API key

### Optional customization:

**Hugging Face Models:**
- `HF_TEXT_MODEL` - Text generation model (default: microsoft/DialoGPT-medium)
- `HF_SPEECH_MODEL` - Speech recognition model (default: openai/whisper-large-v3)
- `HF_TTS_MODEL` - Text-to-speech model (default: microsoft/speecht5_tts)

**Ollama Models:**
- `OLLAMA_TEXT_MODEL` - Text generation model (default: llama2)
- `OLLAMA_SPEECH_MODEL` - Speech recognition model (default: whisper)

**Gemini Models:**
- `GEMINI_MODEL` - Text generation model (default: gemini-pro)

## Provider Comparison

| Feature | Hugging Face | Ollama | Gemini | Original |
|---------|-------------|---------|---------|----------|
| Cost | Free tier | Free | Free tier | Custom |
| Privacy | Cloud | Local | Cloud | Custom |
| Setup Complexity | Low | Medium | Low | High |
| Text Generation | ✅ | ✅ | ✅ | ✅ |
| Speech-to-Text | ✅ | ⚠️ | ⚠️ | ✅ |
| Text-to-Speech | ✅ | ❌ | ⚠️ | ✅ |
| Offline Support | ❌ | ✅ | ❌ | Custom |

## Installation

After choosing your provider, install the required gems:

```bash
bundle install
```

## Testing Your Configuration

You can test your AI provider configuration through the Rails console:

```ruby
# Test the service
ai_service = AiEngineService.new

# Check health
ai_service.health_check

# Test with a sample call (replace with actual call object)
# call = Call.first
# ai_service.notify_new_call(call)
```

## Troubleshooting

### Common Issues:

1. **Provider initialization fails**
   - Check that required environment variables are set
   - Verify API keys are valid
   - Ensure Ollama is running (for Ollama provider)

2. **Health check fails**
   - Verify network connectivity
   - Check API endpoints are accessible
   - Confirm models are available

3. **Audio processing errors**
   - Some providers have limited audio support
   - Consider using text-only interactions for testing
   - Check audio format compatibility

### Logs

Monitor your Rails logs for detailed error messages:

```bash
tail -f log/development.log
```

Provider-specific errors will be prefixed with the provider class name (e.g., `AiProviders::HuggingFaceProvider`).