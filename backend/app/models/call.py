from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime
import json

class CallSession(BaseModel):
    call_id: str
    caller_id: str
    business_id: str
    start_time: datetime
    end_time: Optional[datetime] = None
    status: str = "active"  # active, ended, failed
    conversation_history: List[Dict[str, Any]] = []
    caller_info: Dict[str, Any] = {}
    business_context: Dict[str, Any] = {}
    metadata: Dict[str, Any] = {}
    
    class Config:
        arbitrary_types_allowed = True
    
    def add_exchange(self, user_message: str, ai_response: str):
        """Add a conversation exchange to history"""
        exchange = {
            "timestamp": datetime.utcnow().isoformat(),
            "user": user_message,
            "ai": ai_response
        }
        self.conversation_history.append(exchange)
        
        # Keep only recent exchanges to manage memory
        if len(self.conversation_history) > 20:
            self.conversation_history = self.conversation_history[-20:]
    
    def get_summary(self) -> str:
        """Generate a summary of the call"""
        if not self.conversation_history:
            return "No conversation recorded"
        
        duration = None
        if self.end_time:
            duration = (self.end_time - self.start_time).total_seconds()
        
        summary = f"Call with {self.caller_id}"
        if duration:
            summary += f" lasted {duration:.0f} seconds"
        
        summary += f" with {len(self.conversation_history)} exchanges"
        
        return summary

class CallEvent(BaseModel):
    event_type: str  # call_start, call_end, audio_received, etc.
    call_id: str
    timestamp: datetime
    data: Dict[str, Any]

class ConversationExchange(BaseModel):
    timestamp: datetime
    user_message: str
    ai_response: str
    confidence_score: Optional[float] = None
    intent: Optional[str] = None
    entities: List[Dict[str, Any]] = []
