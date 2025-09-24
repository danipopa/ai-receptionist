# AI Engine

The AI Engine component handles all artificial intelligence processing for the AI Receptionist system, including speech recognition, natural language processing, intent detection, and response generation.

## Overview

The AI Engine is responsible for:
- **Speech-to-Text (STT)**: Converting incoming audio to text transcription
- **Natural Language Understanding (NLU)**: Processing and understanding user intent
- **Dialog Management**: Managing conversation flow and context
- **Response Generation**: Creating appropriate responses using LLM
- **Text-to-Speech (TTS)**: Converting AI responses back to audio
- **Session Management**: Maintaining conversation state across calls

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Audio Input   │───▶│   Speech-to-Text │───▶│      NLU        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  Audio Output   │◀───│  Text-to-Speech  │◀───│ Response Gen    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         ▲
                              ┌─────────────────┐        │
                              │ Dialog Manager  │────────┘
                              └─────────────────┘
                                       │
                              ┌─────────────────┐
                              │ Session Store   │
                              └─────────────────┘
```

## Features

### Speech Recognition
- Real-time audio processing
- Multiple audio format support (WAV, MP3, raw PCM)
- Noise reduction and audio enhancement
- Support for multiple languages

### Natural Language Processing
- Intent classification and entity extraction
- Context-aware conversation management
- Multi-turn dialog support
- Sentiment analysis

### Response Generation
- LLM-powered conversational AI
- Template-based responses for common scenarios
- Personality and tone configuration
- Multi-language response generation

### Integration Points
- REST API for synchronous requests
- WebSocket API for real-time streaming
- Message queue integration for async processing
- Webhook callbacks for external systems

## Installation

### Prerequisites
- Python 3.9+
- CUDA GPU (optional, for faster processing)
- Redis (for session storage)
- OpenAI API key or local LLM setup

### Setup

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Install development dependencies
pip install -r requirements-dev.txt

# Set up environment variables
cp .env.example .env
# Edit .env with your configuration

# Initialize the database
python scripts/init_db.py

# Run the server
python src/main.py
```

## Configuration

Key environment variables:

```bash
# AI Configuration
OPENAI_API_KEY=your_openai_api_key
MODEL_NAME=gpt-4
SPEECH_MODEL=whisper-1
TTS_MODEL=tts-1

# Server Configuration
HOST=localhost
PORT=8081
DEBUG=true

# Storage
REDIS_URL=redis://localhost:6379
SESSION_TIMEOUT=3600

# Audio Processing
SAMPLE_RATE=16000
CHUNK_SIZE=1024
AUDIO_FORMAT=wav
```

## API Endpoints

### Session Management
- `POST /session/create` - Create new conversation session
- `GET /session/{id}` - Get session information
- `DELETE /session/{id}` - End and cleanup session

### Audio Processing
- `POST /process` - Process audio chunk and return response
- `POST /transcribe` - Transcribe audio to text only
- `POST /synthesize` - Convert text to speech

### Real-time Processing
- `WebSocket /ws/stream` - Real-time audio streaming
- `WebSocket /ws/chat` - Text-based chat interface

### Health and Monitoring
- `GET /health` - Service health check
- `GET /metrics` - Performance metrics
- `GET /models` - Available model information

## Development

### Running Tests
```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=src

# Run specific test file
pytest tests/test_speech_recognition.py
```

### Code Quality
```bash
# Format code
black src/ tests/

# Lint code
flake8 src/ tests/

# Type checking
mypy src/
```

### Performance Testing
```bash
# Load testing
python scripts/load_test.py

# Audio processing benchmarks
python scripts/benchmark_audio.py
```