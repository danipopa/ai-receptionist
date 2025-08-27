import aiohttp
import asyncio
import json
import logging
from typing import Dict, Any, Optional
import websockets
from ..config import settings

logger = logging.getLogger(__name__)

class AsteriskService:
    """Service for Asterisk telephony integration via ARI"""
    
    def __init__(self):
        self.ari_url = settings.ASTERISK_ARI_URL
        self.username = settings.ASTERISK_ARI_USERNAME
        self.password = settings.ASTERISK_ARI_PASSWORD
        self.app_name = settings.ASTERISK_ARI_APP
        self.is_initialized = False
        self.websocket = None
        self.active_channels: Dict[str, Dict[str, Any]] = {}
    
    async def initialize(self):
        """Initialize the Asterisk ARI service"""
        try:
            # Test connection to ARI
            async with aiohttp.ClientSession(
                auth=aiohttp.BasicAuth(self.username, self.password)
            ) as session:
                async with session.get(f"{self.ari_url}/ari/asterisk/info") as response:
                    if response.status == 200:
                        self.is_initialized = True
                        logger.info("Asterisk ARI service initialized successfully")
                        
                        # Start WebSocket connection for events
                        asyncio.create_task(self._start_websocket())
                    else:
                        raise RuntimeError(f"Asterisk ARI returned status {response.status}")
                        
        except Exception as e:
            logger.error(f"Failed to initialize Asterisk service: {str(e)}")
            # Don't raise - allow system to work in testing mode
            logger.warning("Continuing without Asterisk - using mock telephony")
    
    async def _start_websocket(self):
        """Start WebSocket connection for real-time events"""
        try:
            ws_url = f"{self.ari_url.replace('http', 'ws')}/ari/events"
            auth_header = aiohttp.BasicAuth(self.username, self.password)
            
            # Connect to WebSocket
            async with websockets.connect(
                ws_url,
                extra_headers={"Authorization": f"Basic {auth_header.encoding}"}
            ) as websocket:
                self.websocket = websocket
                logger.info("Connected to Asterisk WebSocket")
                
                # Listen for events
                async for message in websocket:
                    event = json.loads(message)
                    await self._handle_asterisk_event(event)
                    
        except Exception as e:
            logger.error(f"WebSocket connection error: {str(e)}")
            # Retry connection after delay
            await asyncio.sleep(5)
            asyncio.create_task(self._start_websocket())
    
    async def _handle_asterisk_event(self, event: Dict[str, Any]):
        """Handle incoming Asterisk events"""
        event_type = event.get("type")
        channel = event.get("channel", {})
        channel_id = channel.get("id")
        
        logger.info(f"Asterisk event: {event_type} for channel {channel_id}")
        
        if event_type == "StasisStart":
            # Call entered our application
            await self._handle_call_start(event)
        elif event_type == "StasisEnd":
            # Call left our application
            await self._handle_call_end(event)
        elif event_type == "ChannelHangupRequest":
            # Call hangup requested
            await self._handle_hangup(event)
        elif event_type == "Recording":
            # Audio recording event
            await self._handle_recording(event)
    
    async def _handle_call_start(self, event: Dict[str, Any]):
        """Handle incoming call"""
        channel = event.get("channel", {})
        channel_id = channel.get("id")
        caller_id = channel.get("caller", {}).get("number", "Unknown")
        
        # Extract business ID from args or DID
        args = event.get("args", [])
        business_id = args[0] if args else "default"
        
        # Store channel info
        self.active_channels[channel_id] = {
            "caller_id": caller_id,
            "business_id": business_id,
            "start_time": asyncio.get_event_loop().time(),
            "state": "ringing"
        }
        
        # Answer the call
        await self._answer_channel(channel_id)
        
        # Notify the main application
        # This would trigger the /call/start endpoint
        logger.info(f"Call started: {channel_id} from {caller_id} for business {business_id}")
    
    async def _handle_call_end(self, event: Dict[str, Any]):
        """Handle call termination"""
        channel = event.get("channel", {})
        channel_id = channel.get("id")
        
        if channel_id in self.active_channels:
            # Notify the main application
            # This would trigger the /call/end endpoint
            logger.info(f"Call ended: {channel_id}")
            del self.active_channels[channel_id]
    
    async def _handle_hangup(self, event: Dict[str, Any]):
        """Handle call hangup"""
        channel = event.get("channel", {})
        channel_id = channel.get("id")
        
        logger.info(f"Call hangup: {channel_id}")
    
    async def _handle_recording(self, event: Dict[str, Any]):
        """Handle audio recording events"""
        recording = event.get("recording", {})
        state = recording.get("state")
        
        if state == "done":
            # Recording finished, process audio
            recording_name = recording.get("name")
            logger.info(f"Recording finished: {recording_name}")
            # This would trigger audio processing
    
    async def _answer_channel(self, channel_id: str):
        """Answer an incoming call"""
        try:
            async with aiohttp.ClientSession(
                auth=aiohttp.BasicAuth(self.username, self.password)
            ) as session:
                await session.post(f"{self.ari_url}/ari/channels/{channel_id}/answer")
                
                if channel_id in self.active_channels:
                    self.active_channels[channel_id]["state"] = "answered"
                    
        except Exception as e:
            logger.error(f"Error answering channel {channel_id}: {str(e)}")
    
    async def play_audio(self, call_id: str, audio_data: bytes) -> bool:
        """Play audio to caller"""
        try:
            # Find channel for this call
            channel_id = None
            for ch_id, ch_info in self.active_channels.items():
                if ch_info.get("call_id") == call_id:
                    channel_id = ch_id
                    break
            
            if not channel_id:
                logger.error(f"No active channel found for call {call_id}")
                return False
            
            # Save audio to a temporary file that Asterisk can access
            audio_file = f"/tmp/ai_response_{call_id}.wav"
            with open(audio_file, "wb") as f:
                f.write(audio_data)
            
            # Play the audio file
            async with aiohttp.ClientSession(
                auth=aiohttp.BasicAuth(self.username, self.password)
            ) as session:
                play_data = {
                    "media": f"sound:{audio_file}"
                }
                
                async with session.post(
                    f"{self.ari_url}/ari/channels/{channel_id}/play",
                    json=play_data
                ) as response:
                    if response.status == 200:
                        logger.info(f"Playing audio for call {call_id}")
                        return True
                    else:
                        logger.error(f"Failed to play audio: {response.status}")
                        return False
                        
        except Exception as e:
            logger.error(f"Error playing audio for call {call_id}: {str(e)}")
            return False
    
    async def start_recording(self, call_id: str) -> bool:
        """Start recording caller audio"""
        try:
            # Find channel for this call
            channel_id = None
            for ch_id, ch_info in self.active_channels.items():
                if ch_info.get("call_id") == call_id:
                    channel_id = ch_id
                    break
            
            if not channel_id:
                logger.error(f"No active channel found for call {call_id}")
                return False
            
            # Start recording
            async with aiohttp.ClientSession(
                auth=aiohttp.BasicAuth(self.username, self.password)
            ) as session:
                record_data = {
                    "name": f"recording_{call_id}",
                    "format": "wav",
                    "maxDurationSeconds": 30,
                    "maxSilenceSeconds": 3
                }
                
                async with session.post(
                    f"{self.ari_url}/ari/channels/{channel_id}/record",
                    json=record_data
                ) as response:
                    if response.status == 200:
                        logger.info(f"Started recording for call {call_id}")
                        return True
                    else:
                        logger.error(f"Failed to start recording: {response.status}")
                        return False
                        
        except Exception as e:
            logger.error(f"Error starting recording for call {call_id}: {str(e)}")
            return False
    
    async def hangup_call(self, call_id: str) -> bool:
        """Hangup a call"""
        try:
            # Find channel for this call
            channel_id = None
            for ch_id, ch_info in self.active_channels.items():
                if ch_info.get("call_id") == call_id:
                    channel_id = ch_id
                    break
            
            if not channel_id:
                logger.error(f"No active channel found for call {call_id}")
                return False
            
            # Hangup the channel
            async with aiohttp.ClientSession(
                auth=aiohttp.BasicAuth(self.username, self.password)
            ) as session:
                await session.delete(f"{self.ari_url}/ari/channels/{channel_id}")
                
                logger.info(f"Hung up call {call_id}")
                return True
                
        except Exception as e:
            logger.error(f"Error hanging up call {call_id}: {str(e)}")
            return False
    
    async def health_check(self) -> bool:
        """Check if the service is healthy"""
        try:
            async with aiohttp.ClientSession(
                auth=aiohttp.BasicAuth(self.username, self.password)
            ) as session:
                async with session.get(f"{self.ari_url}/ari/asterisk/info") as response:
                    return response.status == 200
                    
        except Exception:
            return False
    
    def get_active_calls(self) -> Dict[str, Dict[str, Any]]:
        """Get information about active calls"""
        return {
            ch_id: {
                "caller_id": ch_info["caller_id"],
                "business_id": ch_info["business_id"],
                "duration": asyncio.get_event_loop().time() - ch_info["start_time"],
                "state": ch_info["state"]
            }
            for ch_id, ch_info in self.active_channels.items()
        }
