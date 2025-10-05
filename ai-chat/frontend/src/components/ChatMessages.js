import React, { useEffect, useRef } from 'react';

const ChatMessages = ({ messages, isLoading, theme }) => {
  const messagesEndRef = useRef(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages, isLoading]);

  const formatTime = (timestamp) => {
    return new Date(timestamp).toLocaleTimeString([], { 
      hour: '2-digit', 
      minute: '2-digit' 
    });
  };

  const getUserMessageStyles = () => {
    switch (theme) {
      case 'green':
        return { background: 'linear-gradient(135deg, #4ade80 0%, #16a34a 100%)' };
      case 'purple':
        return { background: 'linear-gradient(135deg, #c084fc 0%, #7c3aed 100%)' };
      default:
        return { background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)' };
    }
  };

  const getTypingIndicatorColor = () => {
    switch (theme) {
      case 'green':
        return '#16a34a';
      case 'purple':
        return '#7c3aed';
      default:
        return '#3b82f6';
    }
  };

  return (
    <div 
      style={{
        flex: 1,
        overflowY: 'auto',
        padding: '20px',
        display: 'flex',
        flexDirection: 'column',
        gap: '16px',
        background: '#f9fafb'
      }}
    >
      {messages.map((message) => (
        <div
          key={message.id}
          style={{
            display: 'flex',
            maxWidth: '80%',
            alignSelf: message.isBot ? 'flex-start' : 'flex-end',
            animation: 'fadeIn 0.3s ease-in-out'
          }}
        >
          <div 
            style={{
              backgroundColor: message.isBot ? 'white' : 'transparent',
              padding: '12px 16px',
              borderRadius: '18px',
              boxShadow: '0 2px 8px rgba(0, 0, 0, 0.1)',
              position: 'relative',
              color: message.isBot ? '#1f2937' : 'white',
              border: message.isError ? '1px solid #fecaca' : 'none',
              ...(message.isError && {
                backgroundColor: '#fef2f2',
                color: '#dc2626'
              }),
              ...(!message.isBot && !message.isError && getUserMessageStyles())
            }}
          >
            <div 
              style={{
                fontSize: '14px',
                lineHeight: '1.4',
                marginBottom: '4px'
              }}
            >
              {message.text}
            </div>
            <div 
              style={{
                fontSize: '12px',
                opacity: '0.7',
                textAlign: 'right'
              }}
            >
              {formatTime(message.timestamp)}
            </div>
          </div>
        </div>
      ))}
      
      {isLoading && (
        <div 
          style={{
            display: 'flex',
            maxWidth: '80%',
            alignSelf: 'flex-start',
            animation: 'fadeIn 0.3s ease-in-out'
          }}
        >
          <div 
            style={{
              backgroundColor: 'white',
              padding: '16px 20px',
              borderRadius: '18px',
              boxShadow: '0 2px 8px rgba(0, 0, 0, 0.1)',
              display: 'flex',
              alignItems: 'center',
              gap: '8px'
            }}
          >
            <div 
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '3px'
              }}
            >
              <span 
                style={{
                  width: '8px',
                  height: '8px',
                  backgroundColor: getTypingIndicatorColor(),
                  borderRadius: '50%',
                  animation: 'typing 1.4s infinite ease-in-out',
                  animationDelay: '-0.32s'
                }}
              ></span>
              <span 
                style={{
                  width: '8px',
                  height: '8px',
                  backgroundColor: getTypingIndicatorColor(),
                  borderRadius: '50%',
                  animation: 'typing 1.4s infinite ease-in-out',
                  animationDelay: '-0.16s'
                }}
              ></span>
              <span 
                style={{
                  width: '8px',
                  height: '8px',
                  backgroundColor: getTypingIndicatorColor(),
                  borderRadius: '50%',
                  animation: 'typing 1.4s infinite ease-in-out'
                }}
              ></span>
            </div>
            <span 
              style={{
                fontSize: '12px',
                color: '#6b7280',
                fontStyle: 'italic',
                marginLeft: '4px'
              }}
            >
              AI is typing...
            </span>
          </div>
        </div>
      )}
      
      <div ref={messagesEndRef} />
    </div>
  );
};

export default ChatMessages;