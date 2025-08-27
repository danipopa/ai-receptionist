from fastapi import FastAPI, WebSocket, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
import asyncio
import json
import logging
from typing import Optional, List, Dict, Any
import uuid
from datetime import datetime
import subprocess
import tempfile
import os

from .services.whisper_service import WhisperService
from .services.rasa_service import RasaService
from .services.ollama_service import OllamaService
from .services.tts_service import TTSService
from .services.asterisk_service import AsteriskService
from .models.call import CallSession, CallEvent
from .models.business import Business, Receptionist
from .database import get_db
from .config import settings

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="AI Receptionist API",
    description="Open-source multi-tenant AI receptionist platform",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize services
whisper_service = WhisperService()
rasa_service = RasaService()
ollama_service = OllamaService()
tts_service = TTSService()
asterisk_service = AsteriskService()

# Store active call sessions
active_calls: Dict[str, CallSession] = {}

@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    logger.info("Starting AI Receptionist services...")
    await whisper_service.initialize()
    await rasa_service.initialize()
    await ollama_service.initialize()
    await tts_service.initialize()
    await asterisk_service.initialize()
    logger.info("All services initialized successfully")

@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "message": "AI Receptionist API",
        "version": "1.0.0",
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/health")
async def health_check():
    """Detailed health check for all services"""
    health_status = {
        "whisper": await whisper_service.health_check(),
        "rasa": await rasa_service.health_check(),
        "ollama": await ollama_service.health_check(),
        "tts": await tts_service.health_check(),
        "asterisk": await asterisk_service.health_check()
    }
    
    overall_healthy = all(health_status.values())
    
    return {
        "status": "healthy" if overall_healthy else "degraded",
        "services": health_status,
        "timestamp": datetime.utcnow().isoformat()
    }

@app.post("/call/start")
async def start_call(call_data: dict):
    """Handle incoming call initiation from Asterisk"""
    try:
        call_id = str(uuid.uuid4())
        caller_number = call_data.get("caller_id")
        business_id = call_data.get("business_id")
        
        # Create call session
        call_session = CallSession(
            call_id=call_id,
            caller_id=caller_number,
            business_id=business_id,
            start_time=datetime.utcnow(),
            status="active"
        )
        
        active_calls[call_id] = call_session
        
        # Get business configuration
        business = await get_business_config(business_id)
        
        # Initialize Rasa session for this business
        await rasa_service.start_session(call_id, business.rasa_config)
        
        # Send welcome message
        welcome_text = business.welcome_message or "Hello! Thank you for calling. How can I help you today?"
        
        # Convert to speech
        audio_data = await tts_service.synthesize(
            text=welcome_text,
            voice_config=business.voice_config
        )
        
        # Play welcome message via Asterisk
        await asterisk_service.play_audio(call_id, audio_data)
        
        logger.info(f"Started call {call_id} for business {business_id}")
        
        return {
            "call_id": call_id,
            "status": "started",
            "message": "Call session initialized"
        }
        
    except Exception as e:
        logger.error(f"Error starting call: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/call/{call_id}/audio")
async def process_audio(call_id: str, audio: UploadFile = File(...)):
    """Process incoming audio from caller"""
    try:
        if call_id not in active_calls:
            raise HTTPException(status_code=404, detail="Call session not found")
        
        call_session = active_calls[call_id]
        
        # Save audio to temporary file
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_audio:
            content = await audio.read()
            temp_audio.write(content)
            temp_audio_path = temp_audio.name
        
        try:
            # Transcribe audio to text
            transcription = await whisper_service.transcribe(temp_audio_path)
            
            if not transcription.strip():
                # No speech detected, return silence
                return {"status": "silence"}
            
            logger.info(f"Call {call_id} - Transcribed: {transcription}")
            
            # Process with Rasa
            rasa_response = await rasa_service.process_message(call_id, transcription)
            
            # Generate AI response if needed
            if rasa_response.get("needs_llm", False):
                context = {
                    "conversation_history": call_session.conversation_history,
                    "business_context": call_session.business_context,
                    "caller_info": call_session.caller_info
                }
                
                ai_response = await ollama_service.generate_response(
                    message=transcription,
                    context=context,
                    business_id=call_session.business_id
                )
                
                response_text = ai_response
            else:
                response_text = rasa_response.get("text", "I understand. Please continue.")
            
            # Convert response to speech
            business = await get_business_config(call_session.business_id)
            audio_data = await tts_service.synthesize(
                text=response_text,
                voice_config=business.voice_config
            )
            
            # Play response via Asterisk
            await asterisk_service.play_audio(call_id, audio_data)
            
            # Update conversation history
            call_session.add_exchange(transcription, response_text)
            
            return {
                "status": "processed",
                "transcription": transcription,
                "response": response_text
            }
            
        finally:
            # Clean up temporary file
            os.unlink(temp_audio_path)
            
    except Exception as e:
        logger.error(f"Error processing audio for call {call_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/call/{call_id}/end")
async def end_call(call_id: str):
    """Handle call termination"""
    try:
        if call_id not in active_calls:
            raise HTTPException(status_code=404, detail="Call session not found")
        
        call_session = active_calls[call_id]
        call_session.status = "ended"
        call_session.end_time = datetime.utcnow()
        
        # Save call summary to database
        await save_call_summary(call_session)
        
        # Clean up Rasa session
        await rasa_service.end_session(call_id)
        
        # Remove from active calls
        del active_calls[call_id]
        
        logger.info(f"Ended call {call_id}")
        
        return {
            "status": "ended",
            "duration": (call_session.end_time - call_session.start_time).total_seconds(),
            "summary": call_session.get_summary()
        }
        
    except Exception as e:
        logger.error(f"Error ending call {call_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.websocket("/call/{call_id}/stream")
async def websocket_call_stream(websocket: WebSocket, call_id: str):
    """WebSocket endpoint for real-time call streaming"""
    await websocket.accept()
    
    try:
        if call_id not in active_calls:
            await websocket.send_json({"error": "Call session not found"})
            return
        
        call_session = active_calls[call_id]
        
        while call_session.status == "active":
            # Wait for audio data
            data = await websocket.receive_bytes()
            
            # Process audio in real-time
            # This would integrate with streaming STT/TTS
            
            await asyncio.sleep(0.1)  # Prevent tight loop
            
    except Exception as e:
        logger.error(f"WebSocket error for call {call_id}: {str(e)}")
    finally:
        await websocket.close()

# Business Management Endpoints

@app.get("/businesses")
async def list_businesses():
    """List all businesses"""
    db = get_db()
    businesses = await db.fetch_all("SELECT * FROM businesses ORDER BY name")
    return [dict(business) for business in businesses]

@app.post("/businesses")
async def create_business(business_data: dict):
    """Create a new business"""
    db = get_db()
    
    business_id = str(uuid.uuid4())
    query = """
        INSERT INTO businesses (id, name, phone_number, welcome_message, voice_config, rasa_config)
        VALUES (:id, :name, :phone_number, :welcome_message, :voice_config, :rasa_config)
    """
    
    await db.execute(query, {
        "id": business_id,
        "name": business_data["name"],
        "phone_number": business_data.get("phone_number"),
        "welcome_message": business_data.get("welcome_message"),
        "voice_config": json.dumps(business_data.get("voice_config", {})),
        "rasa_config": json.dumps(business_data.get("rasa_config", {}))
    })
    
    return {"business_id": business_id, "status": "created"}

@app.get("/businesses/{business_id}/calls")
async def get_business_calls(business_id: str, limit: int = 100):
    """Get call history for a business"""
    db = get_db()
    query = """
        SELECT * FROM call_sessions 
        WHERE business_id = :business_id 
        ORDER BY start_time DESC 
        LIMIT :limit
    """
    
    calls = await db.fetch_all(query, {"business_id": business_id, "limit": limit})
    return [dict(call) for call in calls]

# Helper functions

async def get_business_config(business_id: str) -> Business:
    """Get business configuration"""
    db = get_db()
    query = "SELECT * FROM businesses WHERE id = :business_id"
    business = await db.fetch_one(query, {"business_id": business_id})
    
    if not business:
        raise HTTPException(status_code=404, detail="Business not found")
    
    return Business(**dict(business))

async def save_call_summary(call_session: CallSession):
    """Save call summary to database"""
    db = get_db()
    query = """
        INSERT INTO call_sessions (
            id, business_id, caller_id, start_time, end_time, status,
            conversation_history, summary, metadata
        ) VALUES (
            :id, :business_id, :caller_id, :start_time, :end_time, :status,
            :conversation_history, :summary, :metadata
        )
    """
    
    await db.execute(query, {
        "id": call_session.call_id,
        "business_id": call_session.business_id,
        "caller_id": call_session.caller_id,
        "start_time": call_session.start_time,
        "end_time": call_session.end_time,
        "status": call_session.status,
        "conversation_history": json.dumps(call_session.conversation_history),
        "summary": call_session.get_summary(),
        "metadata": json.dumps(call_session.metadata)
    })

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
