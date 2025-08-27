import asyncio
import subprocess
import tempfile
import os
import logging
from typing import Optional
from ..config import settings

logger = logging.getLogger(__name__)

class WhisperService:
    """Service for speech-to-text using Whisper.cpp"""
    
    def __init__(self):
        self.whisper_executable = settings.WHISPER_EXECUTABLE
        self.model_path = settings.WHISPER_MODEL_PATH
        self.is_initialized = False
    
    async def initialize(self):
        """Initialize the Whisper service"""
        try:
            # Check if whisper executable exists
            if not os.path.exists(self.whisper_executable):
                raise FileNotFoundError(f"Whisper executable not found at {self.whisper_executable}")
            
            # Check if model exists
            if not os.path.exists(self.model_path):
                raise FileNotFoundError(f"Whisper model not found at {self.model_path}")
            
            # Test whisper with a dummy command
            test_cmd = [self.whisper_executable, "--help"]
            result = await asyncio.create_subprocess_exec(
                *test_cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            await result.communicate()
            
            if result.returncode == 0:
                self.is_initialized = True
                logger.info("Whisper service initialized successfully")
            else:
                raise RuntimeError("Whisper executable test failed")
                
        except Exception as e:
            logger.error(f"Failed to initialize Whisper service: {str(e)}")
            raise
    
    async def transcribe(self, audio_file_path: str, language: str = "en") -> str:
        """Transcribe audio file to text"""
        if not self.is_initialized:
            raise RuntimeError("Whisper service not initialized")
        
        try:
            # Prepare whisper command
            cmd = [
                self.whisper_executable,
                "-m", self.model_path,
                "-f", audio_file_path,
                "-l", language,
                "--output-txt",
                "--no-timestamps"
            ]
            
            # Run whisper
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                logger.error(f"Whisper transcription failed: {stderr.decode()}")
                return ""
            
            # Parse output
            transcription = stdout.decode().strip()
            logger.info(f"Transcribed: {transcription}")
            
            return transcription
            
        except Exception as e:
            logger.error(f"Error during transcription: {str(e)}")
            return ""
    
    async def transcribe_stream(self, audio_stream) -> str:
        """Transcribe streaming audio (for real-time processing)"""
        # Save stream to temporary file
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
            temp_file.write(audio_stream)
            temp_file_path = temp_file.name
        
        try:
            result = await self.transcribe(temp_file_path)
            return result
        finally:
            # Clean up temporary file
            os.unlink(temp_file_path)
    
    async def health_check(self) -> bool:
        """Check if the service is healthy"""
        try:
            if not self.is_initialized:
                return False
            
            # Quick test with help command
            cmd = [self.whisper_executable, "--help"]
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            await process.communicate()
            
            return process.returncode == 0
            
        except Exception:
            return False
