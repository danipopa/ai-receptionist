# AI Receptionist - Environment Configuration

This document describes the centralized environment configuration for the AI Receptionist project.

## Configuration Files

### Main Configuration
- **`.env`** - Main project configuration with all service settings
- **`docker-compose.yml`** - Uses environment variables from .env

### Service-Specific Configuration  
- **`backend-ai-receptionist/.env`** - Backend-specific variables
- **`frontend-ai-receptionist/.env`** - Frontend-specific variables

## Environment Variables

### Core API Configuration
- `API_HOST` - Backend API hostname (default: localhost)
- `API_PORT` - Backend API port (default: 3000)  
- `API_BASE_URL` - Full backend API URL (default: http://localhost:3000/api/v1)

### Frontend Configuration
- `FRONTEND_HOST` - Frontend hostname (default: localhost)
- `FRONTEND_PORT` - Frontend port (default: 3001)

### Database Configuration
- `DB_HOST` - Database hostname (default: localhost)
- `DB_USER` - Database username (default: root)
- `DB_PASSWORD` - Database password (default: empty)
- `DB_NAME_DEV` - Development database name
- `DB_NAME_TEST` - Test database name

### AI Services Configuration
- `AI_ENGINE_HOST` - AI Engine hostname (default: localhost)
- `AI_ENGINE_PORT` - AI Engine port (default: 8000)
- `AI_FREESWITCH_HOST` - FreeSWITCH service hostname (default: localhost)
- `AI_FREESWITCH_PORT` - FreeSWITCH service port (default: 8001)

## Usage

### Development
1. Copy `.env.example` to `.env` and customize values
2. Each service will read from its local `.env` file
3. Start services normally - they'll use the configured ports

### Docker
```bash
# All services use environment variables from .env
docker-compose up
```

### Manual Service Startup
```bash
# Backend (reads from backend-ai-receptionist/.env)
cd backend-ai-receptionist
bundle exec rails server -p $API_PORT

# Frontend (reads from frontend-ai-receptionist/.env)  
cd frontend-ai-receptionist
npm run dev
```

## Benefits

1. **Single Source of Truth** - All ports and URLs defined in one place
2. **Environment Consistency** - Same configuration across development/Docker/production
3. **Easy Port Changes** - Change API_PORT in .env and all services adapt
4. **Service Discovery** - Services know how to find each other via environment variables
5. **Docker Ready** - Environment variables work seamlessly with Docker Compose

## Migration from Hard-coded Values

Old hard-coded values have been replaced with environment variables:
- Frontend: `localhost:3000` → `$API_BASE_URL`  
- Backend: Database settings → `$DB_*` variables
- Docker: Fixed ports → `$*_PORT` variables

This ensures consistency across all deployment methods.