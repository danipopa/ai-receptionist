from pydantic import BaseModel
from typing import Optional, Dict, Any, List
from datetime import datetime
import json

class Business(BaseModel):
    id: str
    name: str
    phone_number: Optional[str] = None
    welcome_message: Optional[str] = None
    voice_config: Dict[str, Any] = {}
    rasa_config: Dict[str, Any] = {}
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    is_active: bool = True
    
    class Config:
        arbitrary_types_allowed = True

class Receptionist(BaseModel):
    id: str
    business_id: str
    name: str
    personality: str = "professional"
    voice_settings: Dict[str, Any] = {}
    knowledge_base: Dict[str, Any] = {}
    capabilities: List[str] = []
    is_active: bool = True
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    
    class Config:
        arbitrary_types_allowed = True

class VoiceConfig(BaseModel):
    engine: str = "coqui"  # coqui, piper
    model_name: str
    voice_id: Optional[str] = None
    speed: float = 1.0
    pitch: float = 1.0
    language: str = "en"
    
class RasaConfig(BaseModel):
    model_path: str
    confidence_threshold: float = 0.7
    fallback_action: str = "utter_fallback"
    custom_actions_endpoint: Optional[str] = None
