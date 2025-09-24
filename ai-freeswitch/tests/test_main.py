import pytest
import asyncio
import json
from unittest.mock import Mock, AsyncMock, patch
from src.main import FreeSwitchIntegration, CallSession
from datetime import datetime

@pytest.fixture
def config():
    return {
        "ai_engine_url": "http://localhost:8081",
        "backend_url": "http://localhost:3000"
    }

@pytest.fixture
def freeswitch_integration(config):
    return FreeSwitchIntegration(config)

@pytest.mark.asyncio
async def test_call_session_creation():
    """Test CallSession creation"""
    session = CallSession(
        call_id="test-call-123",
        phone_number="+1234567890",
        start_time=datetime.now()
    )
    
    assert session.call_id == "test-call-123"
    assert session.phone_number == "+1234567890"
    assert session.status == "active"
    assert session.ai_engine_session is None

@pytest.mark.asyncio
async def test_handle_call_start(freeswitch_integration):
    """Test handling of new call start"""
    mock_websocket = Mock()
    call_data = {
        "type": "call_start",
        "call_id": "test-call-456",
        "phone_number": "+1987654321"
    }
    
    with patch.object(freeswitch_integration, 'notify_backend') as mock_notify, \
         patch.object(freeswitch_integration, 'initialize_ai_session') as mock_init_ai, \
         patch.object(freeswitch_integration, 'send_audio_response') as mock_send_audio:
        
        mock_init_ai.return_value = "ai-session-123"
        
        await freeswitch_integration.handle_call_start(call_data, mock_websocket)
        
        # Check that call session was created
        assert "test-call-456" in freeswitch_integration.active_calls
        session = freeswitch_integration.active_calls["test-call-456"]
        assert session.phone_number == "+1987654321"
        assert session.ai_engine_session == "ai-session-123"
        
        # Check that backend was notified
        mock_notify.assert_called_once()
        
        # Check that AI session was initialized
        mock_init_ai.assert_called_once_with("test-call-456", "+1987654321")
        
        # Check that welcome message was sent
        mock_send_audio.assert_called_once()

@pytest.mark.asyncio
async def test_handle_call_end(freeswitch_integration):
    """Test handling of call termination"""
    # Setup active call
    session = CallSession(
        call_id="test-call-789",
        phone_number="+1111111111",
        start_time=datetime.now(),
        ai_engine_session="ai-session-789"
    )
    freeswitch_integration.active_calls["test-call-789"] = session
    
    call_data = {
        "type": "call_end",
        "call_id": "test-call-789"
    }
    
    with patch.object(freeswitch_integration, 'notify_backend') as mock_notify, \
         patch.object(freeswitch_integration, 'cleanup_ai_session') as mock_cleanup:
        
        await freeswitch_integration.handle_call_end(call_data)
        
        # Check that call was removed from active calls
        assert "test-call-789" not in freeswitch_integration.active_calls
        
        # Check that backend was notified
        mock_notify.assert_called_once()
        
        # Check that AI session was cleaned up
        mock_cleanup.assert_called_once_with("ai-session-789")

@pytest.mark.asyncio
async def test_process_audio_chunk(freeswitch_integration):
    """Test processing of audio chunks"""
    # Setup active call
    session = CallSession(
        call_id="test-call-audio",
        phone_number="+1222222222",
        start_time=datetime.now(),
        ai_engine_session="ai-session-audio"
    )
    freeswitch_integration.active_calls["test-call-audio"] = session
    
    mock_websocket = Mock()
    audio_data = {
        "type": "audio_chunk",
        "call_id": "test-call-audio",
        "audio_data": "base64_encoded_audio"
    }
    
    mock_ai_response = {
        "text_response": "Thank you for calling. How may I help you?"
    }
    
    with patch.object(freeswitch_integration, 'send_to_ai_engine') as mock_send_ai, \
         patch.object(freeswitch_integration, 'send_audio_response') as mock_send_audio:
        
        mock_send_ai.return_value = mock_ai_response
        
        await freeswitch_integration.process_audio_chunk(audio_data, mock_websocket)
        
        # Check that audio was sent to AI engine
        mock_send_ai.assert_called_once_with("ai-session-audio", "base64_encoded_audio")
        
        # Check that response was sent back
        mock_send_audio.assert_called_once_with(
            mock_websocket, 
            "test-call-audio", 
            "Thank you for calling. How may I help you?"
        )

@pytest.mark.asyncio
async def test_initialize_ai_session(freeswitch_integration):
    """Test AI session initialization"""
    with patch('aiohttp.ClientSession') as mock_session:
        mock_response = Mock()
        mock_response.status = 200
        mock_response.json = AsyncMock(return_value={"session_id": "new-ai-session"})
        
        mock_session.return_value.__aenter__.return_value.post.return_value.__aenter__.return_value = mock_response
        
        session_id = await freeswitch_integration.initialize_ai_session("call-123", "+1333333333")
        
        assert session_id == "new-ai-session"

@pytest.mark.asyncio
async def test_send_to_ai_engine(freeswitch_integration):
    """Test sending audio to AI engine"""
    with patch('aiohttp.ClientSession') as mock_session:
        mock_response = Mock()
        mock_response.status = 200
        mock_response.json = AsyncMock(return_value={
            "text_response": "I understand you need assistance.",
            "confidence": 0.95
        })
        
        mock_session.return_value.__aenter__.return_value.post.return_value.__aenter__.return_value = mock_response
        
        result = await freeswitch_integration.send_to_ai_engine("session-123", "audio_data")
        
        assert result["text_response"] == "I understand you need assistance."
        assert result["confidence"] == 0.95

@pytest.mark.asyncio
async def test_unknown_call_audio_chunk(freeswitch_integration):
    """Test handling audio chunk for unknown call"""
    mock_websocket = Mock()
    audio_data = {
        "type": "audio_chunk",
        "call_id": "unknown-call",
        "audio_data": "base64_encoded_audio"
    }
    
    with patch.object(freeswitch_integration, 'send_to_ai_engine') as mock_send_ai:
        await freeswitch_integration.process_audio_chunk(audio_data, mock_websocket)
        
        # Should not send to AI engine for unknown call
        mock_send_ai.assert_not_called()

if __name__ == "__main__":
    pytest.main([__file__])