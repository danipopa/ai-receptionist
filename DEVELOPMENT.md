# Development Setup Guide

This guide will help you set up the AI Receptionist system for local development.

## Prerequisites

- **Docker & Docker Compose** (recommended)
- **Node.js 18+** (for frontend development)
- **Python 3.9+** (for AI services)
- **Ruby 3.1+** (for Rails backend)
- **MySQL 8.0+** (for database)
- **Redis** (for AI Engine sessions)
- **OpenAI API Key** (required for AI functionality)

## Quick Start (Docker)

1. **Clone and setup**
   ```bash
   git clone <repository-url>
   cd ai-receptionist
   cp .env.example .env
   ```

2. **Configure environment**
   Edit `.env` and add your OpenAI API key:
   ```bash
   OPENAI_API_KEY=your_actual_api_key_here
   ```

3. **Start all services**
   ```bash
   docker-compose up -d
   ```

4. **Initialize database**
   ```bash
   docker-compose exec backend rails db:create db:migrate
   ```

5. **Access services**
   - Frontend: http://localhost:3001
   - Backend API: http://localhost:3000
   - AI Engine: http://localhost:8081/docs (FastAPI docs)
   - Health Check: http://localhost:3000/api/health/all

## Manual Setup (for development)

### 1. Backend Setup (Rails)

```bash
cd backend-ai-receptionist

# Install dependencies
bundle install

# Setup database
rails db:create
rails db:migrate

# Start server
rails server
```

**Environment variables for Rails:**
```bash
export DATABASE_URL="mysql2://username:password@localhost/ai_receptionist_development"
export AI_ENGINE_URL="http://localhost:8081"
export FREESWITCH_URL="http://localhost:8080"
export REDIS_URL="redis://localhost:6379"
```

### 2. Frontend Setup (Nuxt)

```bash
cd frontend-ai-receptionist

# Install dependencies
npm install

# Start development server
npm run dev
```

### 3. AI Engine Setup (Python)

```bash
cd ai-engine

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Set environment variables
export OPENAI_API_KEY="your_api_key_here"
export REDIS_URL="redis://localhost:6379"

# Start server
python src/main.py
```

### 4. AI FreeSWITCH Setup (Python)

```bash
cd ai-freeswitch

# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Set environment variables
export AI_ENGINE_URL="http://localhost:8081"
export BACKEND_URL="http://localhost:3000"

# Start server
python src/main.py
```

## Development Workflow

### Making Changes

1. **Backend API changes**
   - Edit files in `backend-ai-receptionist/`
   - Rails auto-reloads in development
   - Add tests in `test/` directory

2. **Frontend changes**
   - Edit files in `frontend-ai-receptionist/`
   - Nuxt hot-reloads automatically
   - Components in `components/`, pages in `pages/`

3. **AI Engine changes**
   - Edit files in `ai-engine/src/`
   - Restart the Python server manually
   - Add tests in `tests/` directory

4. **FreeSWITCH integration changes**
   - Edit files in `ai-freeswitch/src/`
   - Restart the Python server manually
   - Add tests in `tests/` directory

### Testing

```bash
# Backend tests
cd backend-ai-receptionist
rails test

# AI Engine tests
cd ai-engine
pytest

# FreeSWITCH tests
cd ai-freeswitch
pytest

# Frontend tests (if configured)
cd frontend-ai-receptionist
npm run test
```

### Database Management

```bash
# Create new migration
cd backend-ai-receptionist
rails generate migration AddFieldToModel field:type

# Run migrations
rails db:migrate

# Rollback migration
rails db:rollback

# Reset database (development only)
rails db:drop db:create db:migrate
```

## Service Communication

### API Testing

Test service endpoints:

```bash
# Backend health
curl http://localhost:3000/up

# All services health
curl http://localhost:3000/api/health/all

# AI Engine health
curl http://localhost:8081/health

# FreeSWITCH health
curl http://localhost:8080/health

# Create a test call
curl -X POST http://localhost:3000/api/calls \
  -H "Content-Type: application/json" \
  -d '{"call":{"phone_number":"+1234567890","status":"active"}}'
```

### WebSocket Testing

Test real-time features:

```bash
# AI Engine WebSocket (using wscat)
npm install -g wscat
wscat -c ws://localhost:8081/ws/stream

# Send test message
{"type": "start_session", "data": {"call_id": "test", "phone_number": "+1234567890", "context": "receptionist"}}
```

## Debugging

### Logs

```bash
# Docker Compose logs
docker-compose logs -f [service_name]

# Individual service logs
docker-compose logs backend
docker-compose logs ai-engine
docker-compose logs ai-freeswitch
docker-compose logs frontend

# Follow logs in real-time
docker-compose logs -f --tail=100
```

### Development Tools

1. **Rails Console**
   ```bash
   cd backend-ai-receptionist
   rails console
   ```

2. **AI Engine Interactive**
   ```bash
   cd ai-engine
   python -c "from src.main import *; import asyncio"
   ```

3. **Database Console**
   ```bash
   cd backend-ai-receptionist
   rails dbconsole
   ```

### Common Issues

1. **Port conflicts**
   - Check if ports 3000, 3001, 8080, 8081 are free
   - Modify docker-compose.yml ports if needed

2. **Database connection errors**
   - Ensure MySQL is running
   - Check credentials in .env file
   - Verify database exists

3. **OpenAI API errors**
   - Verify API key is correct
   - Check API quotas and billing
   - Test with a simple API call

4. **Redis connection issues**
   - Ensure Redis is running
   - Check REDIS_URL configuration
   - Test connection: `redis-cli ping`

## Hot Reloading

All services support hot reloading in development:

- **Rails**: Auto-reloads code changes
- **Nuxt**: Hot module replacement
- **Python services**: Restart manually or use tools like `nodemon` equivalent

For Python services with auto-reload:

```bash
# Install watchdog
pip install watchdog

# Use watchmedo for auto-restart
watchmedo auto-restart --directory=./src --pattern=*.py --recursive -- python src/main.py
```

## VS Code Setup

Recommended extensions:
- Ruby (for Rails)
- Python (for AI services)
- Vue.js (for Nuxt frontend)
- Docker
- REST Client (for API testing)

Workspace settings in `.vscode/settings.json`:
```json
{
  "python.defaultInterpreterPath": "./ai-engine/venv/bin/python",
  "ruby.interpreter.commandPath": "ruby",
  "vue.server.hybridMode": true
}
```

## Production Considerations

When ready to deploy:

1. **Environment Configuration**
   - Use production environment variables
   - Set up proper secrets management
   - Configure SSL/TLS certificates

2. **Database Setup**
   - Use production database instance
   - Set up backups and monitoring
   - Configure connection pooling

3. **Scaling**
   - Use container orchestration (Kubernetes)
   - Set up load balancers
   - Configure auto-scaling policies

4. **Monitoring**
   - Set up application monitoring
   - Configure log aggregation
   - Set up alerting for critical issues