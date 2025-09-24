# AI Receptionist System Architecture

This document provides a detailed overview of the AI Receptionist system architecture, component interactions, and technical decisions.

## System Overview

The AI Receptionist is a microservices-based system designed to handle incoming phone calls with artificial intelligence. The system processes speech in real-time, understands caller intent, provides intelligent responses, and can transfer calls to human operators when needed.

## Architecture Principles

### 1. Microservices Architecture
- **Separation of Concerns**: Each service handles a specific domain
- **Independent Deployment**: Services can be deployed and scaled independently
- **Technology Diversity**: Best tool for each job (Rails for API, Python for AI)
- **Fault Isolation**: Failure in one service doesn't bring down the entire system

### 2. Event-Driven Communication
- **Asynchronous Processing**: Non-blocking communication between services
- **Real-time Updates**: WebSocket connections for live audio streaming
- **Event Sourcing**: All call events are logged for audit and replay

### 3. Scalability by Design
- **Horizontal Scaling**: Services can be replicated across multiple instances
- **Stateless Services**: Session state stored externally (Redis)
- **Load Balancing**: Services designed to work behind load balancers

## Component Architecture

### 1. Frontend (Nuxt.js)

```
┌─────────────────────────────────┐
│           Frontend              │
│                                 │
│  ┌─────────────┐ ┌─────────────┐│
│  │   Pages     │ │ Components  ││
│  │             │ │             ││
│  │ • Dashboard │ │ • CallList  ││
│  │ • Calls     │ │ • CallCard  ││
│  │ • Settings  │ │ • Analytics ││
│  └─────────────┘ └─────────────┘│
│                                 │
│  ┌─────────────┐ ┌─────────────┐│
│  │   Store     │ │   Plugins   ││
│  │ (Pinia)     │ │             ││
│  │             │ │ • API       ││
│  │ • calls     │ │ • WebSocket ││
│  │ • auth      │ │ • Utils     ││
│  └─────────────┘ └─────────────┘│
└─────────────────────────────────┘
```

**Responsibilities:**
- Real-time call monitoring dashboard
- Call history and transcript viewing
- System configuration and settings
- Analytics and reporting
- User authentication and authorization

**Technology Stack:**
- **Nuxt.js 3**: Vue.js framework with SSR/SSG
- **Pinia**: State management
- **Nuxt UI**: Component library
- **WebSocket**: Real-time updates

### 2. Backend API (Rails 8)

```
┌─────────────────────────────────┐
│          Backend API            │
│                                 │
│  ┌─────────────┐ ┌─────────────┐│
│  │Controllers  │ │   Models    ││
│  │             │ │             ││
│  │ • CallsCtrl │ │ • Call      ││
│  │ • HealthCtrl│ │ • CallEvent ││
│  │ • APICtrl   │ │ • CallMsg   ││
│  └─────────────┘ └─────────────┘│
│                                 │
│  ┌─────────────┐ ┌─────────────┐│
│  │  Services   │ │    Jobs     ││
│  │             │ │             ││
│  │ • AIEngine  │ │ • CallProc  ││
│  │ • Freeswitch│ │ • Cleanup   ││
│  │ • Analytics │ │ • Reports   ││
│  └─────────────┘ └─────────────┘│
└─────────────────────────────────┘
```

**Responsibilities:**
- RESTful API for all system operations
- Data persistence and management
- Service orchestration and coordination
- Authentication and authorization
- Business logic and workflows
- Event handling from AI services

**Technology Stack:**
- **Rails 8**: Ruby web framework
- **MySQL**: Primary database
- **Redis**: Caching and sessions
- **Solid Queue**: Background job processing
- **HTTParty**: HTTP client for service communication

**Data Models:**
```ruby
# Core entities
Call (id, phone_number, status, duration, ...)
CallEvent (id, call_id, event_type, event_data, timestamp)
CallMessage (id, call_id, role, content, metadata, timestamp)

# Relationships
Call has_many CallEvents
Call has_many CallMessages
```

### 3. AI Engine (Python/FastAPI)

```
┌─────────────────────────────────┐
│           AI Engine             │
│                                 │
│  ┌─────────────┐ ┌─────────────┐│
│  │  Speech     │ │    NLU      ││
│  │ Processing  │ │ Processing  ││
│  │             │ │             ││
│  │ • STT       │ │ • Intent    ││
│  │ • TTS       │ │ • Entities  ││
│  │ • Audio     │ │ • Context   ││
│  └─────────────┘ └─────────────┘│
│                                 │
│  ┌─────────────┐ ┌─────────────┐│
│  │  Dialog     │ │  Session    ││
│  │ Management  │ │ Management  ││
│  │             │ │             ││
│  │ • Flow      │ │ • Storage   ││
│  │ • Context   │ │ • State     ││
│  │ • Response  │ │ • Cleanup   ││
│  └─────────────┘ └─────────────┘│
└─────────────────────────────────┘
```

**Responsibilities:**
- Speech-to-text conversion (OpenAI Whisper)
- Natural language understanding and processing
- Conversation management and context tracking
- Response generation using LLM (GPT)
- Text-to-speech synthesis
- Session state management

**Technology Stack:**
- **FastAPI**: Modern Python web framework
- **OpenAI**: GPT models for conversation and Whisper for STT
- **Redis**: Session storage and caching
- **Pydantic**: Data validation and serialization
- **WebSockets**: Real-time audio streaming

**Processing Pipeline:**
```
Audio Input → STT → NLU → Dialog Manager → LLM → Response → TTS → Audio Output
```

### 4. AI FreeSWITCH (Python)

```
┌─────────────────────────────────┐
│        AI FreeSWITCH            │
│                                 │
│  ┌─────────────┐ ┌─────────────┐│
│  │    Call     │ │   Audio     ││
│  │ Management  │ │ Processing  ││
│  │             │ │             ││
│  │ • Routing   │ │ • Streaming ││
│  │ • Transfer  │ │ • Format    ││
│  │ • Control   │ │ • Buffer    ││
│  └─────────────┘ └─────────────┘│
│                                 │
│  ┌─────────────┐ ┌─────────────┐│
│  │ FreeSWITCH  │ │    AI       ││
│  │ Integration │ │ Integration ││
│  │             │ │             ││
│  │ • Events    │ │ • Sessions  ││
│  │ • Commands  │ │ • Streaming ││
│  │ • Status    │ │ • Responses ││
│  └─────────────┘ └─────────────┘│
└─────────────────────────────────┘
```

**Responsibilities:**
- FreeSWITCH integration and call control
- Real-time audio streaming and processing
- Call routing and transfer management
- Audio format conversion and buffering
- Bridge between telephony and AI systems

**Technology Stack:**
- **Python**: Core language with asyncio
- **WebSockets**: Real-time communication
- **ESL (Event Socket Library)**: FreeSWITCH integration
- **Audio Libraries**: Audio processing and conversion

## Data Flow Architecture

### 1. Call Initiation Flow

```
Phone Call → FreeSWITCH → AI FreeSWITCH → Backend API
                                     ↓
                              AI Engine (Session)
```

**Sequence:**
1. Incoming call hits FreeSWITCH server
2. FreeSWITCH routes call to AI FreeSWITCH integration
3. AI FreeSWITCH notifies Backend API of new call
4. Backend API creates call record in database
5. Backend API requests AI Engine to create session
6. AI Engine initializes conversation session in Redis
7. Welcome message generated and played to caller

### 2. Conversation Flow

```
Caller Audio → AI FreeSWITCH → AI Engine → Response → AI FreeSWITCH → Caller
                    ↓                          ↓
              Backend API ←─────────────────────┘
                    ↓
              Database (logging)
```

**Sequence:**
1. Caller speaks, audio captured by FreeSWITCH
2. AI FreeSWITCH streams audio to AI Engine
3. AI Engine processes audio (STT → NLU → Response Generation)
4. AI Engine returns text response and audio
5. AI FreeSWITCH plays generated audio to caller
6. All interactions logged to Backend API
7. Backend API stores conversation in database

### 3. Call Transfer Flow

```
AI Engine → Backend API → AI FreeSWITCH → FreeSWITCH → Human Operator
```

**Sequence:**
1. AI determines transfer is needed
2. AI Engine requests transfer via Backend API
3. Backend API logs transfer event
4. Backend API instructs AI FreeSWITCH to transfer
5. AI FreeSWITCH commands FreeSWITCH to transfer call
6. Call connected to human operator
7. AI session cleaned up

## Integration Patterns

### 1. Service-to-Service Communication

**HTTP REST APIs:**
- Backend ↔ AI Engine: Session management, health checks
- Backend ↔ AI FreeSWITCH: Call control, status updates
- Frontend ↔ Backend: Data operations, authentication

**WebSocket Connections:**
- AI FreeSWITCH ↔ AI Engine: Real-time audio streaming
- Frontend ↔ Backend: Live call updates (optional)

**Event-Driven Updates:**
- AI services → Backend API: Call events, status changes
- Backend API → Frontend: Real-time dashboard updates

### 2. Data Consistency

**Eventually Consistent:**
- Call events may arrive out of order
- System designed to handle event replay
- Idempotent operations where possible

**ACID Transactions:**
- Database operations within Backend API
- Session state managed atomically in Redis

### 3. Error Handling

**Circuit Breaker Pattern:**
- Services fail gracefully when dependencies are down
- Fallback responses when AI Engine is unavailable

**Retry Mechanisms:**
- Exponential backoff for transient failures
- Dead letter queues for failed messages

**Graceful Degradation:**
- System continues operating with reduced functionality
- Manual override capabilities for critical operations

## Security Architecture

### 1. Authentication & Authorization

**API Security:**
- JWT tokens for API authentication
- Role-based access control (RBAC)
- Rate limiting on public endpoints

**Service-to-Service:**
- Internal network isolation
- Service authentication tokens
- mTLS for production environments

### 2. Data Protection

**Encryption:**
- Data encrypted at rest (database, Redis)
- TLS for all network communication
- Audio data encrypted during transmission

**Privacy:**
- PII detection and handling
- Configurable data retention policies
- GDPR compliance capabilities

### 3. Network Security

**Network Isolation:**
- Services run in isolated networks
- Firewall rules restricting access
- VPN access for management

**Monitoring:**
- Security event logging
- Intrusion detection
- Audit trails for all operations

## Scalability Considerations

### 1. Horizontal Scaling

**Stateless Services:**
- AI Engine: Multiple instances with Redis session store
- AI FreeSWITCH: Load balanced across instances
- Backend API: Standard Rails scaling patterns

**Database Scaling:**
- Read replicas for query distribution
- Database sharding for large datasets
- Connection pooling and optimization

### 2. Performance Optimization

**Caching Strategy:**
- Redis for session data and frequent queries
- CDN for static assets
- API response caching

**Async Processing:**
- Background jobs for non-critical operations
- Message queues for event processing
- Async I/O for network operations

### 3. Resource Management

**Auto-scaling:**
- Container orchestration (Kubernetes)
- CPU/memory-based scaling policies
- Queue depth monitoring for scaling triggers

**Resource Limits:**
- Memory and CPU limits per service
- Rate limiting to prevent resource exhaustion
- Circuit breakers for external dependencies

## Monitoring & Observability

### 1. Health Checks

**Service Health:**
- Individual service health endpoints
- Dependency health verification
- Automated health check aggregation

**System Health:**
- End-to-end call flow testing
- Performance metrics monitoring
- Error rate and latency tracking

### 2. Logging Strategy

**Structured Logging:**
- JSON formatted logs across all services
- Correlation IDs for request tracing
- Standardized log levels and formats

**Log Aggregation:**
- Centralized logging with ELK stack
- Real-time log streaming and alerts
- Long-term log storage and analysis

### 3. Metrics & Alerting

**Key Metrics:**
- Call volume and success rates
- AI response times and accuracy
- System resource utilization
- Error rates and types

**Alerting:**
- Critical system failures
- Performance degradation
- Resource threshold breaches
- Security events

## Future Architecture Considerations

### 1. Multi-tenancy
- Tenant isolation in data and processing
- Per-tenant configuration and customization
- Scaling strategies for multi-tenant deployment

### 2. AI Model Management
- Model versioning and A/B testing
- Custom model training and deployment
- Edge deployment for latency reduction

### 3. Integration Ecosystem
- CRM system integrations
- Calendar and scheduling systems
- Analytics and reporting platforms
- Third-party AI service integrations

This architecture provides a solid foundation for the AI Receptionist system while maintaining flexibility for future enhancements and scaling requirements.