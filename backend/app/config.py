import os
from typing import Optional

class Settings:
    # API Configuration
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    DEBUG: bool = True
    
    # Database
    DATABASE_URL: str = os.getenv("DATABASE_URL", "postgresql://user:password@localhost:5432/ai_receptionist")
    
    # Redis for session storage
    REDIS_URL: str = os.getenv("REDIS_URL", "redis://localhost:6379")
    
    # Whisper Configuration
    WHISPER_MODEL_PATH: str = os.getenv("WHISPER_MODEL_PATH", "./models/ggml-base.en.bin")
    WHISPER_EXECUTABLE: str = os.getenv("WHISPER_EXECUTABLE", "./whisper.cpp/main")
    
    # Rasa Configuration
    RASA_API_URL: str = os.getenv("RASA_API_URL", "http://localhost:5005")
    RASA_TOKEN: Optional[str] = os.getenv("RASA_TOKEN")
    
    # Ollama Configuration
    OLLAMA_API_URL: str = os.getenv("OLLAMA_API_URL", "http://localhost:11434")
    OLLAMA_MODEL: str = os.getenv("OLLAMA_MODEL", "llama3")
    
    # TTS Configuration
    TTS_ENGINE: str = os.getenv("TTS_ENGINE", "coqui")  # coqui or piper
    COQUI_MODEL_PATH: str = os.getenv("COQUI_MODEL_PATH", "./tts_models")
    PIPER_MODEL_PATH: str = os.getenv("PIPER_MODEL_PATH", "./piper_models")
    
    # Asterisk Configuration
    ASTERISK_ARI_URL: str = os.getenv("ASTERISK_ARI_URL", "http://localhost:8088")
    ASTERISK_ARI_USERNAME: str = os.getenv("ASTERISK_ARI_USERNAME", "asterisk")
    ASTERISK_ARI_PASSWORD: str = os.getenv("ASTERISK_ARI_PASSWORD", "asterisk")
    ASTERISK_ARI_APP: str = os.getenv("ASTERISK_ARI_APP", "ai-receptionist")
    
    # Security
    SECRET_KEY: str = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # File Storage
    UPLOAD_DIR: str = os.getenv("UPLOAD_DIR", "./uploads")
    MAX_FILE_SIZE: int = 50 * 1024 * 1024  # 50MB
    
    # Logging
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO")
    LOG_FILE: Optional[str] = os.getenv("LOG_FILE")
    
    # Business Limits
    MAX_CONCURRENT_CALLS_PER_BUSINESS: int = 10
    MAX_CALL_DURATION_MINUTES: int = 30
    
    # AI Configuration
    MAX_CONVERSATION_HISTORY: int = 20  # Number of exchanges to keep in memory
    DEFAULT_RESPONSE_TIMEOUT: int = 5  # Seconds
    
    class Config:
        case_sensitive = True

settings = Settings()
