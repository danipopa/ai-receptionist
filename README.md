# AI Receptionist System

A comprehensive AI-powered receptionist system that handles incoming phone calls, processes speech, generates intelligent responses, and manages call routing through a modern microservices architecture.

## 🏗️ Architecture Overview

The AI Receptionist system consists of four main components:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Frontend      │───▶│   Backend API    │───▶│   AI Engine     │
│   (Nuxt.js)     │    │   (Rails 8)      │    │   (Python)      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        ▲
                                │                        │
                                ▼                        │
                       ┌──────────────────┐              │
                       │  AI FreeSWITCH   │──────────────┘
                       │   (Python)       │
                       └──────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │   Phone System   │
                       │   (FreeSWITCH)   │
                       └──────────────────┘
```

### Components

1. **Frontend (Nuxt.js)** - Web interface for monitoring calls, viewing transcripts, and system management
2. **Backend API (Rails 8)** - Central API handling data persistence, call management, and service coordination
3. **AI Engine (Python/FastAPI)** - Speech processing, natural language understanding, and response generation
4. **AI FreeSWITCH (Python)** - Telephony integration and real-time audio streaming

## 📁 Project Structure

```
ai-receptionist/
├── ai-engine/              # Python AI Engine service
├── ai-freeswitch/          # Python FreeSWITCH integration
├── backend-ai-receptionist/ # Rails 8 API backend
├── frontend-ai-receptionist/ # Nuxt.js frontend
├── freeswitch-k8s-deployment/ # FreeSWITCH Kubernetes configs
├── k8s-manifests/          # Main Kubernetes deployment files
├── docker/                 # Docker compose and configurations
├── scripts/                # Deployment and utility scripts
└── docs/                   # Documentation and guides
```

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose
- OpenAI API key (for AI processing)
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd ai-receptionist
   ```

2. **Set up environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your OpenAI API key and other configuration
   ```

3. **Start all services**
   ```bash
   docker-compose -f docker/docker-compose.yml up -d
   ```

4. **Run database migrations (Rails)**
   ```bash
   docker-compose -f docker/docker-compose.yml exec backend rails db:create db:migrate
   ```

5. **Access the services**
   - Frontend: http://localhost:3001
   - Backend API: http://localhost:3000
   - AI Engine: http://localhost:8081
   - FreeSWITCH Integration: http://localhost:8080

### Development Setup

For local development without Docker:

1. **Backend (Rails)**
   ```bash
   cd backend-ai-receptionist
   bundle install
   rails db:create db:migrate
   rails server
   ```

2. **Frontend (Nuxt)**
   ```bash
   cd frontend-ai-receptionist
   npm install
   npm run dev
   ```

3. **AI Engine**
   ```bash
   cd ai-engine
   pip install -r requirements.txt
   python src/main.py
   ```

4. **AI FreeSWITCH**
   ```bash
   cd ai-freeswitch
   pip install -r requirements.txt
   python src/main.py
   ```

## 📡 API Documentation

### Backend API Endpoints

#### Calls Management
- `GET /api/calls` - List all calls
- `POST /api/calls` - Create new call
- `GET /api/calls/:id` - Get call details
- `POST /api/calls/:id/transfer` - Transfer call
- `GET /api/calls/:id/transcript` - Get call transcript

#### Event Handling
- `POST /api/calls/events` - Handle events from AI services

#### Health Checks
- `GET /api/health/ai_engine` - Check AI Engine status
- `GET /api/health/freeswitch` - Check FreeSWITCH status
- `GET /api/health/all` - Check all services

### AI Engine API

#### Session Management
- `POST /session/create` - Create conversation session
- `GET /session/:id` - Get session details
- `DELETE /session/:id` - End session

#### Audio Processing
- `POST /process` - Process audio and get AI response
- `POST /transcribe` - Transcribe audio to text
- `POST /synthesize` - Convert text to speech

#### Real-time Communication
- `WebSocket /ws/stream` - Real-time audio streaming

### FreeSWITCH Integration API

#### Call Control
- `POST /call/incoming` - Handle incoming call
- `POST /call/transfer` - Transfer active call
- `GET /call/status/:id` - Get call status

#### Real-time Audio
- `WebSocket /ws/audio` - Audio streaming with AI Engine

## 🔧 Configuration

### Environment Variables

Key configuration options:

```bash
# Required
OPENAI_API_KEY=your_api_key

# Service URLs
AI_ENGINE_URL=http://localhost:8081
FREESWITCH_URL=http://localhost:8080
BACKEND_URL=http://localhost:3000

# Database
DATABASE_URL=mysql2://user:pass@localhost/ai_receptionist_dev

# AI Configuration
MODEL_NAME=gpt-3.5-turbo
SESSION_TIMEOUT=3600
```

### FreeSWITCH Configuration

The system includes pre-configured FreeSWITCH settings for:
- SIP profile for AI receptionist
- Dialplan routing incoming calls to AI system
- Event socket configuration for integration
- Audio codec settings optimized for speech processing

See `ai-freeswitch/config/freeswitch_config.md` for detailed configuration.

## 📊 System Flow

### Incoming Call Flow

1. **Call Initiation**
   - Phone call comes into FreeSWITCH
   - FreeSWITCH routes to AI FreeSWITCH integration
   - AI FreeSWITCH notifies Backend API

2. **AI Session Setup**
   - Backend API creates call record
   - AI Engine session is initialized
   - Welcome message is generated and played

3. **Conversation Loop**
   - Audio streams from caller to AI FreeSWITCH
   - Audio sent to AI Engine for processing
   - AI Engine transcribes speech and generates response
   - Response converted to speech and played to caller
   - All interactions logged in Backend API

4. **Call Completion**
   - Call ends naturally or via transfer
   - Sessions cleaned up in AI Engine
   - Final call record updated in Backend API

### Data Flow

```
Caller ──→ FreeSWITCH ──→ AI FreeSWITCH ──→ AI Engine
                              │               │
                              ▼               ▼
                         Backend API ◄────────┘
                              │
                              ▼
                         Frontend UI
```

## 🧪 Testing

### Running Tests

**Backend (Rails)**
```bash
cd backend-ai-receptionist
rails test
```

**AI Engine**
```bash
cd ai-engine
pytest
```

**AI FreeSWITCH**
```bash
cd ai-freeswitch
pytest
```

### Integration Testing

```bash
# Test service connectivity
curl http://localhost:3000/api/health/all

# Test AI Engine
curl http://localhost:8081/health

# Test FreeSWITCH integration
curl http://localhost:8080/health
```

## 🚀 Deployment

### Production Deployment

1. **Set up environment**
   ```bash
   cp .env.example .env.production
   # Configure production values
   ```

2. **Deploy with Docker Compose**
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
   ```

3. **Set up SSL/TLS**
   - Configure reverse proxy (nginx/traefik)
   - Set up SSL certificates
   - Update service URLs

### Scaling Considerations

- **AI Engine**: Can be horizontally scaled with Redis session storage
- **FreeSWITCH**: Multiple instances can be load-balanced
- **Backend**: Standard Rails scaling practices apply
- **Database**: Consider read replicas for high traffic

## 🔒 Security

### Authentication & Authorization

- API endpoints secured with authentication
- Service-to-service communication over private networks
- Environment variables for sensitive configuration

### Data Protection

- Call recordings and transcripts encrypted at rest
- PII handling compliance (configurable retention)
- Audit logging for all call activities

## 📈 Monitoring & Observability

### Health Checks

All services expose health check endpoints for monitoring:

- Backend: `/up` and `/api/health/*`
- AI Engine: `/health`
- FreeSWITCH: `/health`

### Logging

Structured logging across all services:
- Call events and state changes
- AI processing metrics
- Error tracking and alerting

### Metrics

Key metrics to monitor:
- Call volume and duration
- AI response times
- Speech recognition accuracy
- System resource usage

## 🛠️ Development

### Project Structure

```
ai-receptionist/
├── backend-ai-receptionist/     # Rails API backend
├── frontend-ai-receptionist/    # Nuxt.js frontend
├── ai-engine/                   # Python AI processing service
├── ai-freeswitch/              # Python FreeSWITCH integration
├── docker-compose.yml          # Development orchestration
└── .env.example               # Configuration template
```

### Adding Features

1. **New API endpoints**: Add to Rails backend
2. **AI capabilities**: Extend AI Engine with new models/features
3. **Call routing**: Modify FreeSWITCH dialplan and integration
4. **UI features**: Add to Nuxt frontend

### Code Style

- **Rails**: Follow Rails conventions and Rubocop
- **Python**: Use Black formatting and pytest for testing
- **JavaScript**: ESLint and Prettier configuration included

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit pull request

## 📄 License

[Add your license information here]

## 🆘 Support

For support and questions:
- Create an issue in the repository
- Check the troubleshooting section in individual service READMEs
- Review service logs for debugging information

---

## 📚 Documentation

For detailed information, see the documentation in the `docs/` directory:

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) - System architecture and design
- [`docs/DEPLOYMENT-STEPS.md`](docs/DEPLOYMENT-STEPS.md) - Step-by-step deployment guide  
- [`docs/KUBERNETES-DEPLOYMENT.md`](docs/KUBERNETES-DEPLOYMENT.md) - Kubernetes deployment instructions
- [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) - Development setup and guidelines
- [`docs/CONFIG.md`](docs/CONFIG.md) - Configuration reference
- [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) - Common issues and solutions

## 🛠️ Scripts

Utility scripts are located in the `scripts/` directory:

- `scripts/build-and-push-images.sh` - Build and push Docker images
- `scripts/deploy-k8s.sh` - Deploy to Kubernetes
- `scripts/setup-storage.sh` - Set up persistent storage
- `scripts/cleanup-storage.sh` - Clean up storage volumes

## Troubleshooting

### Common Issues

1. **Service connectivity errors**
   - Check Docker network configuration
   - Verify environment variables
   - Check service health endpoints

2. **AI Engine not responding**
   - Verify OpenAI API key is set
   - Check Redis connectivity
   - Review AI Engine logs

3. **Audio quality issues**
   - Check FreeSWITCH codec configuration
   - Verify network bandwidth
   - Review audio processing settings

4. **Database connection errors**
   - Ensure MySQL is running
   - Check database credentials
   - Verify network connectivity

### Getting Help

Each service directory contains detailed README files with specific setup and troubleshooting information.