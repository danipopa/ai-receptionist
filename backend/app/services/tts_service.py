import asyncio
import subprocess
import tempfile
import os
import logging
from typing import Dict, Any, Optional
import json
from ..config import settings

logger = logging.getLogger(__name__)

class TTSService:
    """Service for text-to-speech using Coqui TTS or Piper"""
    
    def __init__(self):
        self.engine = settings.TTS_ENGINE
        self.coqui_model_path = settings.COQUI_MODEL_PATH
        self.piper_model_path = settings.PIPER_MODEL_PATH
        self.is_initialized = False
    
    async def initialize(self):
        """Initialize the TTS service"""
        try:
            if self.engine == "coqui":
                await self._initialize_coqui()
            elif self.engine == "piper":
                await self._initialize_piper()
            else:
                raise ValueError(f"Unsupported TTS engine: {self.engine}")
                
            self.is_initialized = True
            logger.info(f"TTS service initialized with engine: {self.engine}")
            
        except Exception as e:
            logger.error(f"Failed to initialize TTS service: {str(e)}")
            raise
    
    async def _initialize_coqui(self):
        """Initialize Coqui TTS"""
        try:
            # Test Coqui TTS import
            import TTS
            from TTS.api import TTS as TTSModel
            
            # Check if model directory exists
            if not os.path.exists(self.coqui_model_path):
                os.makedirs(self.coqui_model_path, exist_ok=True)
            
            logger.info("Coqui TTS initialized successfully")
            
        except ImportError:
            raise ImportError("Coqui TTS not installed. Install with: pip install TTS")
    
    async def _initialize_piper(self):
        """Initialize Piper TTS"""
        try:
            # Check if piper executable exists
            piper_executable = "piper"  # Assumes piper is in PATH
            
            # Test piper
            test_cmd = [piper_executable, "--help"]
            result = await asyncio.create_subprocess_exec(
                *test_cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            await result.communicate()
            
            if result.returncode != 0:
                raise RuntimeError("Piper executable test failed")
            
            logger.info("Piper TTS initialized successfully")
            
        except FileNotFoundError:
            raise FileNotFoundError("Piper executable not found. Install Piper TTS")
    
    async def synthesize(self, text: str, voice_config: Dict[str, Any] = None) -> bytes:
        """Synthesize text to speech"""
        if not self.is_initialized:
            raise RuntimeError("TTS service not initialized")
        
        if not text.strip():
            return b""  # Return empty audio for empty text
        
        try:
            if self.engine == "coqui":
                return await self._synthesize_coqui(text, voice_config)
            elif self.engine == "piper":
                return await self._synthesize_piper(text, voice_config)
            else:
                raise ValueError(f"Unsupported TTS engine: {self.engine}")
                
        except Exception as e:
            logger.error(f"Error synthesizing speech: {str(e)}")
            # Return empty audio on error
            return b""
    
    async def _synthesize_coqui(self, text: str, voice_config: Dict[str, Any] = None) -> bytes:
        """Synthesize using Coqui TTS"""
        from TTS.api import TTS as TTSModel
        
        # Default voice configuration
        model_name = "tts_models/en/ljspeech/tacotron2-DDC"
        if voice_config:
            model_name = voice_config.get("model_name", model_name)
        
        # Create temporary output file
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
            temp_file_path = temp_file.name
        
        try:
            # Initialize TTS model
            tts = TTSModel(model_name=model_name)
            
            # Generate speech
            tts.tts_to_file(text=text, file_path=temp_file_path)
            
            # Read generated audio
            with open(temp_file_path, "rb") as audio_file:
                audio_data = audio_file.read()
            
            return audio_data
            
        finally:
            # Clean up temporary file
            if os.path.exists(temp_file_path):
                os.unlink(temp_file_path)
    
    async def _synthesize_piper(self, text: str, voice_config: Dict[str, Any] = None) -> bytes:
        """Synthesize using Piper TTS"""
        # Default voice configuration
        model_path = os.path.join(self.piper_model_path, "en_US-lessac-medium.onnx")
        if voice_config:
            model_path = voice_config.get("model_path", model_path)
        
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Piper model not found: {model_path}")
        
        # Create temporary output file
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
            temp_file_path = temp_file.name
        
        try:
            # Prepare piper command
            cmd = [
                "piper",
                "--model", model_path,
                "--output_file", temp_file_path
            ]
            
            # Run piper
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            # Send text to stdin
            stdout, stderr = await process.communicate(input=text.encode())
            
            if process.returncode != 0:
                logger.error(f"Piper synthesis failed: {stderr.decode()}")
                return b""
            
            # Read generated audio
            with open(temp_file_path, "rb") as audio_file:
                audio_data = audio_file.read()
            
            return audio_data
            
        finally:
            # Clean up temporary file
            if os.path.exists(temp_file_path):
                os.unlink(temp_file_path)
    
    async def get_available_voices(self) -> list:
        """Get list of available voices"""
        if self.engine == "coqui":
            return await self._get_coqui_voices()
        elif self.engine == "piper":
            return await self._get_piper_voices()
        else:
            return []
    
    async def _get_coqui_voices(self) -> list:
        """Get available Coqui TTS voices"""
        try:
            from TTS.api import TTS as TTSModel
            
            # Get list of available models
            models = TTSModel.list_models()
            
            # Filter for TTS models
            tts_models = [model for model in models if model.startswith("tts_models")]
            
            return tts_models
            
        except Exception as e:
            logger.error(f"Error getting Coqui voices: {str(e)}")
            return []
    
    async def _get_piper_voices(self) -> list:
        """Get available Piper voices"""
        try:
            voices = []
            
            if os.path.exists(self.piper_model_path):
                for file in os.listdir(self.piper_model_path):
                    if file.endswith(".onnx"):
                        voices.append(file)
            
            return voices
            
        except Exception as e:
            logger.error(f"Error getting Piper voices: {str(e)}")
            return []
    
    async def health_check(self) -> bool:
        """Check if the service is healthy"""
        try:
            if not self.is_initialized:
                return False
            
            # Test synthesis with a short phrase
            test_text = "Hello"
            audio_data = await self.synthesize(test_text)
            
            return len(audio_data) > 0
            
        except Exception:
            return False
