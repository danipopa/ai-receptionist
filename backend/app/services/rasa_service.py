import aiohttp
import asyncio
import json
import logging
from typing import Dict, Any, Optional
from ..config import settings

logger = logging.getLogger(__name__)

class RasaService:
    """Service for conversation management using Rasa"""
    
    def __init__(self):
        self.rasa_url = settings.RASA_API_URL
        self.token = settings.RASA_TOKEN
        self.sessions: Dict[str, Dict[str, Any]] = {}
        self.is_initialized = False
    
    async def initialize(self):
        """Initialize the Rasa service"""
        try:
            # Test connection to Rasa
            async with aiohttp.ClientSession() as session:
                headers = {}
                if self.token:
                    headers["Authorization"] = f"Bearer {self.token}"
                
                async with session.get(f"{self.rasa_url}/status", headers=headers) as response:
                    if response.status == 200:
                        self.is_initialized = True
                        logger.info("Rasa service initialized successfully")
                    else:
                        raise RuntimeError(f"Rasa API returned status {response.status}")
                        
        except Exception as e:
            logger.error(f"Failed to initialize Rasa service: {str(e)}")
            # Don't raise - allow system to work without Rasa for basic responses
            logger.warning("Continuing without Rasa - using fallback responses")
    
    async def start_session(self, session_id: str, business_config: Dict[str, Any]):
        """Start a new conversation session"""
        self.sessions[session_id] = {
            "business_config": business_config,
            "conversation_history": [],
            "context": {},
            "created_at": asyncio.get_event_loop().time()
        }
        
        if self.is_initialized:
            try:
                # Initialize Rasa conversation
                await self._send_rasa_event(session_id, {
                    "event": "session_started"
                })
                
                # Send business context
                await self._send_rasa_event(session_id, {
                    "event": "slot",
                    "name": "business_context",
                    "value": business_config
                })
                
            except Exception as e:
                logger.error(f"Error starting Rasa session {session_id}: {str(e)}")
    
    async def process_message(self, session_id: str, message: str) -> Dict[str, Any]:
        """Process a user message and return response"""
        if session_id not in self.sessions:
            raise ValueError(f"Session {session_id} not found")
        
        session = self.sessions[session_id]
        
        # Add to conversation history
        session["conversation_history"].append({
            "type": "user",
            "message": message,
            "timestamp": asyncio.get_event_loop().time()
        })
        
        if self.is_initialized:
            try:
                # Send message to Rasa
                response = await self._send_message_to_rasa(session_id, message)
                
                # Parse Rasa response
                rasa_response = await self._parse_rasa_response(response)
                
                # Add AI response to history
                session["conversation_history"].append({
                    "type": "ai",
                    "message": rasa_response.get("text", ""),
                    "intent": rasa_response.get("intent"),
                    "confidence": rasa_response.get("confidence"),
                    "timestamp": asyncio.get_event_loop().time()
                })
                
                return rasa_response
                
            except Exception as e:
                logger.error(f"Error processing message with Rasa: {str(e)}")
                # Fallback to simple responses
                return await self._generate_fallback_response(message, session)
        else:
            # Use fallback responses when Rasa is not available
            return await self._generate_fallback_response(message, session)
    
    async def end_session(self, session_id: str):
        """End a conversation session"""
        if session_id in self.sessions:
            if self.is_initialized:
                try:
                    await self._send_rasa_event(session_id, {
                        "event": "session_ended"
                    })
                except Exception as e:
                    logger.error(f"Error ending Rasa session {session_id}: {str(e)}")
            
            del self.sessions[session_id]
    
    async def _send_message_to_rasa(self, session_id: str, message: str) -> Dict[str, Any]:
        """Send message to Rasa and get response"""
        headers = {"Content-Type": "application/json"}
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        
        payload = {
            "sender": session_id,
            "message": message
        }
        
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{self.rasa_url}/webhooks/rest/webhook",
                json=payload,
                headers=headers
            ) as response:
                if response.status == 200:
                    return await response.json()
                else:
                    raise RuntimeError(f"Rasa API returned status {response.status}")
    
    async def _send_rasa_event(self, session_id: str, event: Dict[str, Any]):
        """Send event to Rasa"""
        headers = {"Content-Type": "application/json"}
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        
        payload = {
            "sender": session_id,
            "event": event
        }
        
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{self.rasa_url}/conversations/{session_id}/tracker/events",
                json=payload,
                headers=headers
            ) as response:
                if response.status != 200:
                    logger.warning(f"Failed to send Rasa event: {response.status}")
    
    async def _parse_rasa_response(self, rasa_response: Any) -> Dict[str, Any]:
        """Parse Rasa response into standardized format"""
        if isinstance(rasa_response, list) and len(rasa_response) > 0:
            response = rasa_response[0]
            
            return {
                "text": response.get("text", ""),
                "intent": response.get("intent", {}).get("name"),
                "confidence": response.get("intent", {}).get("confidence"),
                "entities": response.get("entities", []),
                "needs_llm": "custom" in response.get("custom", {}),
                "custom": response.get("custom", {})
            }
        
        return {
            "text": "I understand. Please continue.",
            "needs_llm": True
        }
    
    async def _generate_fallback_response(self, message: str, session: Dict[str, Any]) -> Dict[str, Any]:
        """Generate simple fallback responses when Rasa is not available"""
        message_lower = message.lower()
        
        # Simple keyword-based responses
        if any(word in message_lower for word in ["hello", "hi", "hey"]):
            return {
                "text": "Hello! How can I help you today?",
                "needs_llm": False
            }
        elif any(word in message_lower for word in ["appointment", "schedule", "book"]):
            return {
                "text": "I'd be happy to help you schedule an appointment. Let me connect you with someone who can assist you.",
                "needs_llm": False
            }
        elif any(word in message_lower for word in ["hours", "open", "time"]):
            return {
                "text": "Our business hours vary. Let me get you the current information.",
                "needs_llm": True
            }
        elif any(word in message_lower for word in ["bye", "goodbye", "thanks"]):
            return {
                "text": "Thank you for calling! Have a great day!",
                "needs_llm": False
            }
        else:
            return {
                "text": "I understand. Let me help you with that.",
                "needs_llm": True
            }
    
    async def health_check(self) -> bool:
        """Check if the service is healthy"""
        try:
            async with aiohttp.ClientSession() as session:
                headers = {}
                if self.token:
                    headers["Authorization"] = f"Bearer {self.token}"
                
                async with session.get(f"{self.rasa_url}/status", headers=headers) as response:
                    return response.status == 200
                    
        except Exception:
            return False
