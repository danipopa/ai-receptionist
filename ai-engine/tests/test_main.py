import pytest
import asyncio
import json
import base64
from unittest.mock import Mock, AsyncMock, patch
from datetime import datetime
from src.main import AIEngine, ConversationSession, CreateSessionRequest, ProcessAudioRequest

@pytest.fixture
def config():
    return {
        "OPENAI_API_KEY": "test-key",
        "MODEL_NAME": "gpt-3.5-turbo",
        "REDIS_URL": "redis://localhost:6379",
        "HOST": "localhost",
        "PORT": 8081,
        "DEBUG": True
    }

@pytest.fixture
def ai_engine(config):
    return AIEngine(config)

@pytest.fixture
def sample_session():
    return ConversationSession(
        session_id="test-session-123",
        call_id="test-call-456",
        phone_number="+1234567890",
        context="receptionist",
        language="en-US",
        created_at=datetime.now(),
        last_activity=datetime.now(),
        messages=[],
        user_profile={}
    )

@pytest.mark.asyncio
async def test_conversation_session_creation():
    """Test ConversationSession creation and initialization"""
    session = ConversationSession(
        session_id="test-123",
        call_id="call-456",
        phone_number="+1111111111",
        context="test",
        language="en-US",
        created_at=datetime.now(),
        last_activity=datetime.now()
    )
    
    assert session.session_id == "test-123"
    assert session.call_id == "call-456"
    assert session.phone_number == "+1111111111"
    assert session.messages == []
    assert session.user_profile == {}

@pytest.mark.asyncio
async def test_create_conversation_session(ai_engine):
    """Test creating a new conversation session"""
    request = CreateSessionRequest(
        call_id="test-call-789",
        phone_number="+1987654321",
        context="receptionist",
        language="en-US"
    )
    
    with patch.object(ai_engine, 'redis', new=AsyncMock()) as mock_redis:
        mock_redis.setex = AsyncMock()
        
        result = await ai_engine.create_conversation_session(request)
        
        assert "session_id" in result
        assert result["status"] == "created"
        assert "welcome_message" in result
        mock_redis.setex.assert_called_once()

@pytest.mark.asyncio
async def test_speech_to_text(ai_engine):
    """Test speech-to-text functionality"""
    # Mock audio bytes
    audio_bytes = b"fake_audio_data"
    
    with patch.object(ai_engine.openai_client.audio.transcriptions, 'create') as mock_transcribe:
        mock_response = Mock()
        mock_response.text = "Hello, how are you?"
        mock_transcribe.return_value = mock_response
        
        result = await ai_engine.speech_to_text(audio_bytes, "en-US")
        
        assert result == "Hello, how are you?"
        mock_transcribe.assert_called_once()

@pytest.mark.asyncio
async def test_generate_response(ai_engine, sample_session):
    """Test AI response generation"""
    user_input = "I need help with my account"
    
    with patch.object(ai_engine.openai_client.chat.completions, 'create') as mock_chat:
        mock_response = Mock()
        mock_response.choices = [Mock()]
        mock_response.choices[0].message.content = "I'd be happy to help you with your account. What specific assistance do you need?"
        mock_chat.return_value = mock_response
        
        result = await ai_engine.generate_response(sample_session, user_input)
        
        assert "account" in result.lower()
        assert "help" in result.lower()
        mock_chat.assert_called_once()

@pytest.mark.asyncio
async def test_text_to_speech_bytes(ai_engine):
    """Test text-to-speech conversion"""
    text = "Thank you for calling. How may I help you?"
    
    with patch.object(ai_engine.openai_client.audio.speech, 'create') as mock_tts:
        mock_response = Mock()
        mock_response.content = b"fake_audio_bytes"
        mock_tts.return_value = mock_response
        
        result = await ai_engine.text_to_speech_bytes(text)
        
        assert result == b"fake_audio_bytes"
        mock_tts.assert_called_once()

@pytest.mark.asyncio
async def test_process_audio_chunk(ai_engine, sample_session):
    """Test processing audio chunk end-to-end"""
    # Mock base64 encoded audio
    audio_data = base64.b64encode(b"fake_audio").decode()
    
    request = ProcessAudioRequest(
        session_id="test-session-123",
        audio_data=audio_data,
        format="wav"
    )
    
    with patch.object(ai_engine, 'get_conversation_session') as mock_get_session, \
         patch.object(ai_engine, 'speech_to_text') as mock_stt, \
         patch.object(ai_engine, 'generate_response') as mock_generate, \
         patch.object(ai_engine, 'text_to_speech_bytes') as mock_tts, \
         patch.object(ai_engine, 'save_conversation_session') as mock_save:
        
        mock_get_session.return_value = sample_session
        mock_stt.return_value = "Hello, I need assistance"
        mock_generate.return_value = "I'm here to help you. What can I do for you?"
        mock_tts.return_value = b"response_audio_bytes"
        
        result = await ai_engine.process_audio_chunk(request)
        
        assert result["transcript"] == "Hello, I need assistance"
        assert result["text_response"] == "I'm here to help you. What can I do for you?"
        assert "audio_response" in result
        assert result["session_id"] == "test-session-123"
        
        # Verify session was updated
        assert len(sample_session.messages) == 2
        assert sample_session.messages[0]["role"] == "user"
        assert sample_session.messages[1]["role"] == "assistant"

@pytest.mark.asyncio
async def test_build_system_prompt(ai_engine):
    """Test system prompt building"""
    context = "receptionist"
    phone_number = "+1234567890"
    
    prompt = ai_engine.build_system_prompt(context, phone_number)
    
    assert "AI receptionist" in prompt
    assert phone_number in prompt
    assert context in prompt
    assert "professional" in prompt

@pytest.mark.asyncio
async def test_get_conversation_session_not_found(ai_engine):
    """Test getting non-existent session"""
    with patch.object(ai_engine, 'redis', new=AsyncMock()) as mock_redis:
        mock_redis.get.return_value = None
        
        result = await ai_engine.get_conversation_session("non-existent")
        
        assert result is None

@pytest.mark.asyncio
async def test_cleanup_session(ai_engine):
    """Test session cleanup"""
    session_id = "test-cleanup-session"
    
    with patch.object(ai_engine, 'redis', new=AsyncMock()) as mock_redis:
        mock_redis.delete = AsyncMock()
        
        result = await ai_engine.cleanup_session(session_id)
        
        assert result["status"] == "session_ended"
        assert result["session_id"] == session_id
        mock_redis.delete.assert_called_once_with(f"session:{session_id}")

@pytest.mark.asyncio
async def test_transcribe_speech_api_endpoint(ai_engine):
    """Test transcribe API endpoint"""
    from src.main import TranscribeRequest
    
    request = TranscribeRequest(
        audio_data=base64.b64encode(b"fake_audio").decode(),
        language="en-US"
    )
    
    with patch.object(ai_engine, 'speech_to_text') as mock_stt:
        mock_stt.return_value = "Transcribed text"
        
        result = await ai_engine.transcribe_speech(request)
        
        assert result["transcript"] == "Transcribed text"
        assert result["language"] == "en-US"
        assert "confidence" in result

@pytest.mark.asyncio
async def test_empty_transcript_handling(ai_engine, sample_session):
    """Test handling of empty transcripts"""
    audio_data = base64.b64encode(b"silent_audio").decode()
    
    request = ProcessAudioRequest(
        session_id="test-session-123",
        audio_data=audio_data
    )
    
    with patch.object(ai_engine, 'get_conversation_session') as mock_get_session, \
         patch.object(ai_engine, 'speech_to_text') as mock_stt:
        
        mock_get_session.return_value = sample_session
        mock_stt.return_value = ""  # Empty transcript
        
        result = await ai_engine.process_audio_chunk(request)
        
        assert "didn't catch that" in result["text_response"].lower()

if __name__ == "__main__":
    pytest.main([__file__])