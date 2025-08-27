import aiohttp
import asyncio
import json
import logging
from typing import Dict, Any, Optional, List
from ..config import settings

logger = logging.getLogger(__name__)

class OllamaService:
    """Service for LLM inference using Ollama"""
    
    def __init__(self):
        self.ollama_url = settings.OLLAMA_API_URL
        self.model = settings.OLLAMA_MODEL
        self.is_initialized = False
        self.business_contexts: Dict[str, Dict[str, Any]] = {}
    
    async def initialize(self):
        """Initialize the Ollama service"""
        try:
            # Test connection to Ollama
            async with aiohttp.ClientSession() as session:
                async with session.get(f"{self.ollama_url}/api/tags") as response:
                    if response.status == 200:
                        models = await response.json()
                        available_models = [model["name"] for model in models.get("models", [])]
                        
                        if self.model in available_models:
                            self.is_initialized = True
                            logger.info(f"Ollama service initialized with model: {self.model}")
                        else:
                            logger.error(f"Model {self.model} not found. Available models: {available_models}")
                            raise RuntimeError(f"Model {self.model} not available")
                    else:
                        raise RuntimeError(f"Ollama API returned status {response.status}")
                        
        except Exception as e:
            logger.error(f"Failed to initialize Ollama service: {str(e)}")
            raise
    
    async def generate_response(
        self, 
        message: str, 
        context: Dict[str, Any], 
        business_id: str
    ) -> str:
        """Generate AI response using Ollama"""
        if not self.is_initialized:
            raise RuntimeError("Ollama service not initialized")
        
        try:
            # Build context-aware prompt
            prompt = await self._build_prompt(message, context, business_id)
            
            # Generate response
            response = await self._call_ollama(prompt)
            
            # Clean and validate response
            cleaned_response = self._clean_response(response)
            
            logger.info(f"Generated response for business {business_id}: {cleaned_response[:100]}...")
            
            return cleaned_response
            
        except Exception as e:
            logger.error(f"Error generating response: {str(e)}")
            return "I apologize, but I'm having trouble processing your request right now. Please hold while I connect you with someone who can help."
    
    async def _call_ollama(self, prompt: str) -> str:
        """Make API call to Ollama"""
        payload = {
            "model": self.model,
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": 0.7,
                "top_p": 0.9,
                "max_tokens": 150,
                "stop": ["Human:", "Caller:"]
            }
        }
        
        headers = {"Content-Type": "application/json"}
        
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{self.ollama_url}/api/generate",
                json=payload,
                headers=headers
            ) as response:
                if response.status == 200:
                    result = await response.json()
                    return result.get("response", "")
                else:
                    raise RuntimeError(f"Ollama API returned status {response.status}")
    
    async def _build_prompt(self, message: str, context: Dict[str, Any], business_id: str) -> str:
        """Build context-aware prompt for the LLM"""
        business_context = context.get("business_context", {})
        conversation_history = context.get("conversation_history", [])
        caller_info = context.get("caller_info", {})
        
        # Get business-specific information
        business_name = business_context.get("name", "the business")
        business_type = business_context.get("type", "company")
        services = business_context.get("services", [])
        hours = business_context.get("hours", "regular business hours")
        
        # Build system prompt
        system_prompt = f"""You are a professional AI receptionist for {business_name}, a {business_type}. 

Your responsibilities:
- Answer questions about the business professionally and helpfully
- Schedule appointments when requested
- Take messages for staff members
- Provide information about services and hours
- Transfer calls when appropriate
- Maintain a friendly, professional tone

Business Information:
- Name: {business_name}
- Type: {business_type}
- Services: {', '.join(services) if services else 'various services'}
- Hours: {hours}

Guidelines:
- Keep responses concise (1-2 sentences)
- Be helpful and professional
- If you don't know something, offer to connect them with someone who can help
- For appointments, gather: name, phone, preferred date/time, reason for visit
- For messages, gather: name, phone, message content, urgency level

"""
        
        # Add conversation history
        if conversation_history:
            system_prompt += "\nRecent conversation:\n"
            for exchange in conversation_history[-5:]:  # Last 5 exchanges
                if exchange.get("user"):
                    system_prompt += f"Caller: {exchange['user']}\n"
                if exchange.get("ai"):
                    system_prompt += f"Receptionist: {exchange['ai']}\n"
        
        # Add current message
        system_prompt += f"\nCaller: {message}\nReceptionist:"
        
        return system_prompt
    
    def _clean_response(self, response: str) -> str:
        """Clean and validate the LLM response"""
        # Remove any unwanted prefixes/suffixes
        response = response.strip()
        
        # Remove common LLM artifacts
        prefixes_to_remove = ["Receptionist:", "AI:", "Assistant:"]
        for prefix in prefixes_to_remove:
            if response.startswith(prefix):
                response = response[len(prefix):].strip()
        
        # Ensure response isn't too long
        if len(response) > 300:
            # Find the last complete sentence within 300 chars
            sentences = response.split('. ')
            truncated = ""
            for sentence in sentences:
                if len(truncated + sentence + '. ') <= 300:
                    truncated += sentence + '. '
                else:
                    break
            response = truncated.strip()
        
        # Ensure response isn't empty
        if not response:
            response = "I understand. How can I help you with that?"
        
        return response
    
    async def set_business_context(self, business_id: str, context: Dict[str, Any]):
        """Set business-specific context for better responses"""
        self.business_contexts[business_id] = context
    
    async def health_check(self) -> bool:
        """Check if the service is healthy"""
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(f"{self.ollama_url}/api/tags") as response:
                    return response.status == 200
                    
        except Exception:
            return False
    
    async def get_available_models(self) -> List[str]:
        """Get list of available models"""
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(f"{self.ollama_url}/api/tags") as response:
                    if response.status == 200:
                        models = await response.json()
                        return [model["name"] for model in models.get("models", [])]
                    return []
                    
        except Exception:
            return []
