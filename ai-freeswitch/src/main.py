import asyncio
import websockets
import json
import logging
from typing import Dict, Optional
from datetime import datetime
import aiohttp
from dataclasses import dataclass

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class CallSession:
    """Represents an active call session"""
    call_id: str
    phone_number: str
    start_time: datetime
    status: str = "active"
    ai_engine_session: Optional[str] = None

class FreeSwitchIntegration:
    """Main class for FreeSWITCH integration with AI engine"""
    
    def __init__(self, config: Dict):
        self.config = config
        self.active_calls: Dict[str, CallSession] = {}
        self.ai_engine_url = config.get("ai_engine_url", "http://localhost:8081")
        self.backend_url = config.get("backend_url", "http://localhost:3000")
        
    async def start_server(self):
        """Start the WebSocket server for audio streaming"""
        logger.info("Starting FreeSWITCH Integration Server")
        
        # Start WebSocket server for audio streaming
        start_server = websockets.serve(
            self.handle_audio_stream, 
            "0.0.0.0", 
            8080
        )
        
        await start_server
        logger.info("WebSocket server started on ws://0.0.0.0:8080")
        
    async def handle_audio_stream(self, websocket, path):
        """Handle incoming audio stream from FreeSWITCH"""
        try:
            async for message in websocket:
                data = json.loads(message)
                
                if data.get("type") == "call_start":
                    await self.handle_call_start(data, websocket)
                elif data.get("type") == "audio_chunk":
                    await self.process_audio_chunk(data, websocket)
                elif data.get("type") == "call_end":
                    await self.handle_call_end(data)
                    
        except websockets.exceptions.ConnectionClosed:
            logger.info("WebSocket connection closed")
        except Exception as e:
            logger.error(f"Error handling audio stream: {e}")
            
    async def handle_call_start(self, data: Dict, websocket):
        """Handle new incoming call"""
        call_id = data.get("call_id")
        phone_number = data.get("phone_number", "unknown")
        
        logger.info(f"New call started: {call_id} from {phone_number}")
        
        # Create call session
        session = CallSession(
            call_id=call_id,
            phone_number=phone_number,
            start_time=datetime.now()
        )
        self.active_calls[call_id] = session
        
        # Notify backend about new call
        await self.notify_backend("call_start", {
            "call_id": call_id,
            "phone_number": phone_number,
            "timestamp": session.start_time.isoformat()
        })
        
        # Initialize AI engine session
        ai_session = await self.initialize_ai_session(call_id, phone_number)
        session.ai_engine_session = ai_session
        
        # Send welcome message
        await self.send_audio_response(websocket, call_id, "Hello! How can I help you today?")
        
    async def process_audio_chunk(self, data: Dict, websocket):
        """Process incoming audio chunk and send to AI engine"""
        call_id = data.get("call_id")
        audio_data = data.get("audio_data")
        
        if call_id not in self.active_calls:
            logger.warning(f"Received audio for unknown call: {call_id}")
            return
            
        session = self.active_calls[call_id]
        
        try:
            # Send audio to AI engine for processing
            response = await self.send_to_ai_engine(session.ai_engine_session, audio_data)
            
            if response and response.get("text_response"):
                # Send AI response back as audio
                await self.send_audio_response(websocket, call_id, response["text_response"])
                
        except Exception as e:
            logger.error(f"Error processing audio chunk: {e}")
            
    async def handle_call_end(self, data: Dict):
        """Handle call termination"""
        call_id = data.get("call_id")
        
        if call_id in self.active_calls:
            session = self.active_calls[call_id]
            session.status = "ended"
            
            logger.info(f"Call ended: {call_id}")
            
            # Notify backend about call end
            await self.notify_backend("call_end", {
                "call_id": call_id,
                "duration": (datetime.now() - session.start_time).total_seconds()
            })
            
            # Cleanup AI engine session
            if session.ai_engine_session:
                await self.cleanup_ai_session(session.ai_engine_session)
                
            # Remove from active calls
            del self.active_calls[call_id]
            
    async def initialize_ai_session(self, call_id: str, phone_number: str) -> str:
        """Initialize a new AI engine session"""
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(f"{self.ai_engine_url}/session/create", json={
                    "call_id": call_id,
                    "phone_number": phone_number,
                    "context": "receptionist"
                }) as response:
                    if response.status == 200:
                        result = await response.json()
                        return result.get("session_id")
                    else:
                        logger.error(f"Failed to create AI session: {response.status}")
                        return None
        except Exception as e:
            logger.error(f"Error initializing AI session: {e}")
            return None
            
    async def send_to_ai_engine(self, session_id: str, audio_data: str) -> Optional[Dict]:
        """Send audio data to AI engine for processing"""
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(f"{self.ai_engine_url}/process", json={
                    "session_id": session_id,
                    "audio_data": audio_data,
                    "format": "base64"
                }) as response:
                    if response.status == 200:
                        return await response.json()
                    else:
                        logger.error(f"AI engine request failed: {response.status}")
                        return None
        except Exception as e:
            logger.error(f"Error sending to AI engine: {e}")
            return None
            
    async def send_audio_response(self, websocket, call_id: str, text: str):
        """Convert text to speech and send back to caller"""
        try:
            # This would integrate with TTS service
            response_data = {
                "type": "audio_response",
                "call_id": call_id,
                "text": text,
                "audio_data": "base64_encoded_audio_data"  # Placeholder
            }
            
            await websocket.send(json.dumps(response_data))
            
        except Exception as e:
            logger.error(f"Error sending audio response: {e}")
            
    async def notify_backend(self, event_type: str, data: Dict):
        """Notify Rails backend about call events"""
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(f"{self.backend_url}/api/calls/events", json={
                    "event_type": event_type,
                    "data": data
                }) as response:
                    if response.status != 200:
                        logger.warning(f"Backend notification failed: {response.status}")
        except Exception as e:
            logger.error(f"Error notifying backend: {e}")
            
    async def cleanup_ai_session(self, session_id: str):
        """Cleanup AI engine session"""
        try:
            async with aiohttp.ClientSession() as session:
                async with session.delete(f"{self.ai_engine_url}/session/{session_id}"):
                    pass
        except Exception as e:
            logger.error(f"Error cleaning up AI session: {e}")

async def main():
    """Main entry point"""
    config = {
        "ai_engine_url": "http://localhost:8081",
        "backend_url": "http://localhost:3000"
    }
    
    integration = FreeSwitchIntegration(config)
    await integration.start_server()
    
    # Keep the server running
    await asyncio.Future()  # Run forever

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Server stopped by user")