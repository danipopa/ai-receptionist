# AI Receptionist - Open Source Multi-Tenant Platform

🤖 **An intelligent, privacy-first AI receptionist that handles phone calls, schedules appointments, and provides natural conversations using local open-source technologies.**

## 🎯 Project Goals

- **Multi-tenant platform** supporting multiple businesses
- **Phone call handling**: answer, route, take messages, schedule appointments
- **Natural conversations** using local open-source LLMs
- **Privacy-friendly** - all processing happens locally
- **Scalable and cost-effective** deployment
- **Self-service dashboard** for clients to manage their AI receptionists

## 🏗️ Architecture Overview

```
         Incoming Call
              │
     [ Asterisk / FreeSWITCH ]
              │  SIP / RTP
              ▼
     Whisper.cpp (STT)
   (real-time transcription)
              │
   ┌──────────▼──────────┐
   │     RASA Engine     │  ← manages conversation flows
   └──────────▲──────────┘
              │
     Ollama + LLaMA-3
  (local AI assistant)
              │
     Coqui TTS / Piper
   (generate natural voice)
              │
     [ Asterisk / FreeSWITCH ]
              │
         Caller Hears AI
```

## 🛠️ Technology Stack

| Layer | Component | Solution | Why |
|-------|-----------|----------|-----|
| **Telephony** | Call handling | Asterisk/FreeSWITCH | Mature, SIP/PSTN ready |
| **STT** | Speech→Text | Whisper.cpp | Fast, accurate, local |
| **AI Brain** | Conversations | Rasa + Ollama (LLaMA-3) | Context-aware + powerful |
| **TTS** | Text→Speech | Coqui TTS/Piper | Natural voices, multilingual |
| **Orchestration** | API Layer | FastAPI | High-performance Python |
| **Dashboard** | Client UI | React + Next.js | Modern, responsive |
| **Deployment** | Scaling | Docker + Kubernetes | Production-ready |

## 📁 Project Structure

```
AI-Receptionist/
├── backend/                 # FastAPI orchestration layer
│   ├── app/
│   ├── requirements.txt
│   └── Dockerfile
├── frontend/               # React dashboard
│   ├── src/
│   ├── package.json
│   └── Dockerfile
├── telephony/             # Asterisk/FreeSWITCH configs
│   ├── asterisk/
│   └── freeswitch/
├── ai-engine/             # Rasa + AI components
│   ├── rasa/
│   ├── whisper/
│   ├── ollama/
│   └── tts/
├── deployment/            # Docker & K8s configs
│   ├── docker-compose.yml
│   ├── kubernetes/
│   └── helm/
└── docs/                  # Documentation
    ├── setup/
    ├── api/
    └── deployment/
```

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- Node.js 18+
- Python 3.9+
- Asterisk or FreeSWITCH

### 1. Clone and Setup
```bash
git clone <your-repo>
cd AI-Receptionist
cp .env.example .env
```

### 2. Start with Docker Compose
```bash
docker-compose up -d
```

### 3. Access the Dashboard
- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- API Docs: http://localhost:8000/docs

## 🎯 Features

### ✅ Core Features
- [x] Multi-business support
- [x] Real-time call handling
- [x] Natural language conversations
- [x] Appointment scheduling
- [x] Message taking
- [x] Call routing
- [x] Custom voices per business
- [x] Local LLM processing (privacy-first)

### 🔄 Advanced Features
- [x] Calendar integrations (Google, Outlook)
- [x] CRM integrations
- [x] Voicemail fallback
- [x] Analytics dashboard
- [x] A/B testing for conversations
- [x] Multi-language support

## 📚 Documentation

- [Setup Guide](docs/setup/README.md)
- [API Documentation](docs/api/README.md)
- [Deployment Guide](docs/deployment/README.md)
- [Architecture Deep Dive](docs/architecture.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Whisper.cpp](https://github.com/ggerganov/whisper.cpp) for speech recognition
- [Rasa](https://rasa.com/) for conversation management
- [Ollama](https://ollama.com/) for local LLM inference
- [Coqui TTS](https://github.com/coqui-ai/TTS) for speech synthesis
- [Asterisk](https://www.asterisk.org/) for telephony
