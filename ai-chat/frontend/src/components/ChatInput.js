import React, { useState, useRef, useEffect } from 'react';

const ChatInput = ({ onSendMessage, placeholder, disabled, theme }) => {
  const [message, setMessage] = useState('');
  const textareaRef = useRef(null);

  const handleSubmit = (e) => {
    e.preventDefault();
    if (message.trim() && !disabled) {
      onSendMessage(message.trim());
      setMessage('');
      if (textareaRef.current) {
        textareaRef.current.style.height = 'auto';
      }
    }
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit(e);
    }
  };

  const handleInputChange = (e) => {
    setMessage(e.target.value);
    
    // Auto-resize textarea
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
      textareaRef.current.style.height = textareaRef.current.scrollHeight + 'px';
    }
  };

  useEffect(() => {
    if (textareaRef.current && !disabled) {
      textareaRef.current.focus();
    }
  }, [disabled]);

  const getSendButtonStyles = () => {
    switch (theme) {
      case 'green':
        return { background: 'linear-gradient(135deg, #4ade80 0%, #16a34a 100%)' };
      case 'purple':
        return { background: 'linear-gradient(135deg, #c084fc 0%, #7c3aed 100%)' };
      default:
        return { background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)' };
    }
  };

  return (
    <div 
      style={{
        padding: '16px',
        backgroundColor: 'white',
        borderTop: '1px solid #e5e7eb'
      }}
    >
      <form 
        onSubmit={handleSubmit} 
        style={{ 
          display: 'flex', 
          gap: '8px' 
        }}
      >
        <div 
          style={{
            display: 'flex',
            alignItems: 'flex-end',
            gap: '8px',
            backgroundColor: '#f3f4f6',
            borderRadius: '25px',
            padding: '8px 12px',
            flex: 1
          }}
        >
          <textarea
            ref={textareaRef}
            value={message}
            onChange={handleInputChange}
            onKeyPress={handleKeyPress}
            placeholder={placeholder || 'Type your message...'}
            disabled={disabled}
            rows={1}
            style={{
              flex: 1,
              border: 0,
              backgroundColor: 'transparent',
              resize: 'none',
              outline: 'none',
              fontSize: '14px',
              lineHeight: '1.4',
              maxHeight: '100px',
              minHeight: '20px',
              fontFamily: 'inherit',
              color: disabled ? '#9ca3af' : '#1f2937'
            }}
          />
          <button
            type="submit"
            disabled={!message.trim() || disabled}
            style={{
              border: 0,
              color: 'white',
              width: '36px',
              height: '36px',
              borderRadius: '50%',
              cursor: disabled || !message.trim() ? 'not-allowed' : 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              transition: 'all 0.2s ease',
              opacity: disabled || !message.trim() ? 0.5 : 1,
              transform: 'scale(1)',
              ...(!disabled && message.trim() && getSendButtonStyles())
            }}
            title="Send message"
            onMouseEnter={(e) => {
              if (!disabled && message.trim()) {
                e.target.style.transform = 'scale(1.05)';
              }
            }}
            onMouseLeave={(e) => {
              e.target.style.transform = 'scale(1)';
            }}
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path
                d="M2 21L23 12L2 3V10L17 12L2 14V21Z"
                fill="currentColor"
              />
            </svg>
          </button>
        </div>
      </form>
    </div>
  );
};

export default ChatInput;