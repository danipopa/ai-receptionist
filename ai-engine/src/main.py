import asyncio
import logging
import json
import base64
import io
import wave
from typing import Dict, Optional, List
from datetime import datetime, timedelta
from dataclasses import dataclass, asdict
from uuid import uuid4

import aioredis
import openai
from fastapi import FastAPI, WebSocket, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import speech_recognition as sr
from gtts import gTTS
import numpy as np
from scipy.io import wavfile

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Data models
class CreateSessionRequest(BaseModel):
    call_id: str
    phone_number: str
    context: str = "receptionist"
    language: str = "en-US"

class ProcessAudioRequest(BaseModel):
    session_id: str
    audio_data: str  # base64 encoded
    format: str = "wav"

class TranscribeRequest(BaseModel):
    audio_data: str
    language: str = "en-US"

class SynthesizeRequest(BaseModel):
    text: str
    voice: str = "alloy"
    format: str = "mp3"

@dataclass
class ConversationSession:
    """Represents an active conversation session"""
    session_id: str
    call_id: str
    phone_number: str
    context: str
    language: str
    created_at: datetime
    last_activity: datetime
    messages: List[Dict] = None
    user_profile: Dict = None

    def __post_init__(self):
        if self.messages is None:
            self.messages = []
        if self.user_profile is None:
            self.user_profile = {}

class AIEngine:
    """Main AI Engine class handling all AI processing"""
    
    def __init__(self, config: Dict):
        self.config = config
        self.redis = None
        self.openai_client = openai.AsyncOpenAI(api_key=config.get("OPENAI_API_KEY"))
        self.speech_recognizer = sr.Recognizer()
        
        # Initialize FastAPI app
        self.app = FastAPI(title="AI Engine", version="1.0.0")
        self.setup_middleware()
        self.setup_routes()
        
    def setup_middleware(self):
        """Setup FastAPI middleware"""
        self.app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )
        
    def setup_routes(self):
        """Setup API routes"""
        
        @self.app.on_event("startup")
        async def startup():
            await self.initialize_redis()
            
        @self.app.on_event("shutdown")
        async def shutdown():
            if self.redis:
                await self.redis.close()
                
        @self.app.get("/health")
        async def health_check():
            return {"status": "healthy", "timestamp": datetime.now().isoformat()}
            
        @self.app.post("/session/create")
        async def create_session(request: CreateSessionRequest):
            return await self.create_conversation_session(request)
            
        @self.app.get("/session/{session_id}")
        async def get_session(session_id: str):
            return await self.get_conversation_session(session_id)
            
        @self.app.delete("/session/{session_id}")
        async def delete_session(session_id: str):
            return await self.cleanup_session(session_id)
            
        @self.app.post("/process")
        async def process_audio(request: ProcessAudioRequest):
            return await self.process_audio_chunk(request)
            
        @self.app.post("/transcribe")
        async def transcribe_audio(request: TranscribeRequest):
            return await self.transcribe_speech(request)
            
        @self.app.post("/synthesize")
        async def synthesize_speech(request: SynthesizeRequest):
            return await self.text_to_speech(request)
            
        @self.app.websocket("/ws/stream")
        async def websocket_stream(websocket: WebSocket):
            await self.handle_audio_stream(websocket)
            
    async def initialize_redis(self):
        """Initialize Redis connection for session storage"""
        try:
            redis_url = self.config.get("REDIS_URL", "redis://localhost:6379")
            self.redis = aioredis.from_url(redis_url)
            await self.redis.ping()
            logger.info("Connected to Redis")
        except Exception as e:
            logger.error(f"Failed to connect to Redis: {e}")
            
    async def create_conversation_session(self, request: CreateSessionRequest) -> Dict:
        """Create a new conversation session"""
        session_id = str(uuid4())
        
        session = ConversationSession(
            session_id=session_id,
            call_id=request.call_id,
            phone_number=request.phone_number,
            context=request.context,
            language=request.language,
            created_at=datetime.now(),
            last_activity=datetime.now()
        )
        
        # Store session in Redis
        if self.redis:
            await self.redis.setex(
                f"session:{session_id}",
                3600,  # 1 hour TTL
                json.dumps(asdict(session), default=str)
            )
            
        logger.info(f"Created session {session_id} for call {request.call_id}")
        
        return {
            "session_id": session_id,
            "status": "created",
            "welcome_message": "Hello! How can I help you today?"
        }
        
    async def get_conversation_session(self, session_id: str) -> Optional[ConversationSession]:
        """Retrieve conversation session from storage"""
        if not self.redis:
            return None
            
        try:
            session_data = await self.redis.get(f"session:{session_id}")
            if session_data:
                data = json.loads(session_data)
                return ConversationSession(**data)
        except Exception as e:
            logger.error(f"Error retrieving session {session_id}: {e}")
            
        return None
        
    async def save_conversation_session(self, session: ConversationSession):
        """Save conversation session to storage"""
        if not self.redis:
            return
            
        try:
            session.last_activity = datetime.now()
            await self.redis.setex(
                f"session:{session.session_id}",
                3600,
                json.dumps(asdict(session), default=str)
            )
        except Exception as e:
            logger.error(f"Error saving session {session.session_id}: {e}")
            
    async def process_audio_chunk(self, request: ProcessAudioRequest) -> Dict:
        """Process incoming audio chunk and return AI response"""
        session = await self.get_conversation_session(request.session_id)
        if not session:
            raise HTTPException(status_code=404, detail="Session not found")
            
        try:
            # Decode audio data
            audio_bytes = base64.b64decode(request.audio_data)
            
            # Transcribe speech to text
            transcript = await self.speech_to_text(audio_bytes, session.language)
            
            if not transcript.strip():
                return {"text_response": "I didn't catch that. Could you please repeat?"}
                
            logger.info(f"Transcribed: {transcript}")
            
            # Add user message to conversation
            session.messages.append({
                "role": "user",
                "content": transcript,
                "timestamp": datetime.now().isoformat()
            })
            
            # Generate AI response
            ai_response = await self.generate_response(session, transcript)
            
            # Add AI response to conversation
            session.messages.append({
                "role": "assistant",
                "content": ai_response,
                "timestamp": datetime.now().isoformat()
            })
            
            # Save updated session
            await self.save_conversation_session(session)
            
            # Generate speech audio for response
            audio_data = await self.text_to_speech_bytes(ai_response)
            
            return {
                "text_response": ai_response,
                "transcript": transcript,
                "audio_response": base64.b64encode(audio_data).decode() if audio_data else None,
                "session_id": session.session_id
            }
            
        except Exception as e:
            logger.error(f"Error processing audio: {e}")
            return {"text_response": "I'm having trouble processing your request. Please try again."}
            
    async def speech_to_text(self, audio_bytes: bytes, language: str = "en-US") -> str:
        """Convert speech audio to text using OpenAI Whisper"""
        try:
            # Create a temporary file-like object
            audio_file = io.BytesIO(audio_bytes)
            audio_file.name = "audio.wav"
            
            # Use OpenAI Whisper API
            response = await self.openai_client.audio.transcriptions.create(
                model="whisper-1",
                file=audio_file,
                language=language.split("-")[0]  # Convert en-US to en
            )
            
            return response.text
            
        except Exception as e:
            logger.error(f"Speech recognition error: {e}")
            return ""
            
    async def generate_response(self, session: ConversationSession, user_input: str) -> str:
        """Generate AI response using OpenAI GPT"""
        try:
            # Build conversation context
            system_prompt = self.build_system_prompt(session.context, session.phone_number)
            
            messages = [{"role": "system", "content": system_prompt}]
            
            # Add conversation history (last 10 messages to stay within limits)
            for message in session.messages[-10:]:
                messages.append({
                    "role": message["role"],
                    "content": message["content"]
                })
                
            # Add current user input
            messages.append({"role": "user", "content": user_input})
            
            # Generate response
            response = await self.openai_client.chat.completions.create(
                model=self.config.get("MODEL_NAME", "gpt-3.5-turbo"),
                messages=messages,
                max_tokens=150,
                temperature=0.7
            )
            
            return response.choices[0].message.content.strip()
            
        except Exception as e:
            logger.error(f"Error generating response: {e}")
            return "I apologize, but I'm having difficulty processing your request right now."
            
    def build_system_prompt(self, context: str, phone_number: str) -> str:
        """Build system prompt for the AI receptionist"""
        return f"""
        You are a professional AI receptionist for our company. Your role is to:
        
        1. Greet callers warmly and professionally
        2. Understand their needs and direct them appropriately
        3. Provide helpful information about our services
        4. Schedule appointments or transfer calls when needed
        5. Handle common inquiries efficiently
        
        Guidelines:
        - Keep responses concise and professional
        - Be helpful and courteous at all times
        - If you cannot help with something, offer to transfer to a human
        - Remember the caller's phone number is {phone_number}
        - Context: {context}
        
        Always maintain a friendly, professional tone and ask clarifying questions when needed.
        """
        
    async def text_to_speech_bytes(self, text: str) -> Optional[bytes]:
        """Convert text to speech and return audio bytes"""
        try:
            # Use OpenAI TTS API
            response = await self.openai_client.audio.speech.create(
                model="tts-1",
                voice="alloy",
                input=text
            )
            
            return response.content
            
        except Exception as e:
            logger.error(f"Text-to-speech error: {e}")
            return None
            
    async def transcribe_speech(self, request: TranscribeRequest) -> Dict:
        """Transcribe audio to text only"""
        try:
            audio_bytes = base64.b64decode(request.audio_data)
            transcript = await self.speech_to_text(audio_bytes, request.language)
            
            return {
                "transcript": transcript,
                "language": request.language,
                "confidence": 0.95  # Placeholder confidence score
            }
            
        except Exception as e:
            logger.error(f"Transcription error: {e}")
            raise HTTPException(status_code=500, detail="Transcription failed")
            
    async def text_to_speech(self, request: SynthesizeRequest) -> Dict:
        """Convert text to speech"""
        try:
            audio_bytes = await self.text_to_speech_bytes(request.text)
            
            if audio_bytes:
                return {
                    "audio_data": base64.b64encode(audio_bytes).decode(),
                    "format": request.format,
                    "text": request.text
                }
            else:
                raise HTTPException(status_code=500, detail="Speech synthesis failed")
                
        except Exception as e:
            logger.error(f"TTS error: {e}")
            raise HTTPException(status_code=500, detail="Speech synthesis failed")
            
    async def cleanup_session(self, session_id: str) -> Dict:
        """Clean up and end conversation session"""
        if self.redis:
            await self.redis.delete(f"session:{session_id}")
            
        logger.info(f"Cleaned up session {session_id}")
        
        return {"status": "session_ended", "session_id": session_id}
        
    async def handle_audio_stream(self, websocket: WebSocket):
        """Handle real-time audio streaming via WebSocket"""
        await websocket.accept()
        session_id = None
        
        try:
            while True:
                data = await websocket.receive_text()
                message = json.loads(data)
                
                if message.get("type") == "start_session":
                    # Create new session for WebSocket
                    request = CreateSessionRequest(**message["data"])
                    result = await self.create_conversation_session(request)
                    session_id = result["session_id"]
                    
                    await websocket.send_text(json.dumps({
                        "type": "session_created",
                        "session_id": session_id,
                        "message": result["welcome_message"]
                    }))
                    
                elif message.get("type") == "audio_chunk" and session_id:
                    # Process audio chunk
                    request = ProcessAudioRequest(
                        session_id=session_id,
                        audio_data=message["audio_data"]
                    )
                    
                    result = await self.process_audio_chunk(request)
                    
                    await websocket.send_text(json.dumps({
                        "type": "ai_response",
                        "data": result
                    }))
                    
        except Exception as e:
            logger.error(f"WebSocket error: {e}")
        finally:
            if session_id:
                await self.cleanup_session(session_id)

async def main():
    """Main entry point"""
    import uvicorn
    from os import getenv
    
    config = {
        "OPENAI_API_KEY": getenv("OPENAI_API_KEY"),
        "MODEL_NAME": getenv("MODEL_NAME", "gpt-3.5-turbo"),
        "REDIS_URL": getenv("REDIS_URL", "redis://localhost:6379"),
        "HOST": getenv("HOST", "localhost"),
        "PORT": int(getenv("PORT", 8081)),
        "DEBUG": getenv("DEBUG", "false").lower() == "true"
    }
    
    ai_engine = AIEngine(config)
    
    logger.info("Starting AI Engine server...")
    
    await uvicorn.run(
        ai_engine.app,
        host=config["HOST"],
        port=config["PORT"],
        log_level="info" if config["DEBUG"] else "warning"
    )

if __name__ == "__main__":
    asyncio.run(main())