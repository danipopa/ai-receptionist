# AI FreeSWITCH Component

This component handles telephony and VoIP communications for the AI Receptionist system. It integrates with FreeSWITCH to manage incoming calls, audio streaming, and call routing.

## Overview

The AI FreeSWITCH component is responsible for:
- Managing incoming phone calls
- Converting audio streams for AI processing
- Handling call routing and transfer
- Managing conference calls and hold functionality
- Integrating with the AI engine for real-time conversation

## Architecture

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────┐
│   Phone Call    │────│ FreeSWITCH   │────│ AI Engine   │
└─────────────────┘    └──────────────┘    └─────────────┘
                              │
                              │
                       ┌──────────────┐
                       │ Rails Backend│
                       └──────────────┘
```

## Prerequisites

- FreeSWITCH installed and configured
- Python 3.8+ for the integration layer
- WebSocket support for real-time communication
- Audio processing libraries (libsndfile, ffmpeg)

## Installation

1. Install FreeSWITCH dependencies
2. Set up Python virtual environment
3. Install required Python packages
4. Configure FreeSWITCH modules
5. Set up WebSocket endpoints

## Configuration

See `config/` directory for:
- FreeSWITCH configuration files
- SIP settings
- Audio codec configurations
- Routing dialplans

## Development

```bash
# Start the FreeSWITCH integration service
python src/main.py

# Run tests
python -m pytest tests/

# Check service status
curl http://localhost:8080/health
```

## API Endpoints

- `POST /call/incoming` - Handle incoming call
- `POST /call/transfer` - Transfer active call
- `GET /call/status/:id` - Get call status
- `WebSocket /ws/audio` - Real-time audio streaming