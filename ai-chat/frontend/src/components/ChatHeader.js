import React from 'react';

const ChatHeader = ({ onClose, onToggleFAQs, showFAQs, theme }) => {
  const getThemeStyles = () => {
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
      className={`chat-header-container theme-${theme}`}
      style={{
        padding: '16px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        color: 'white',
        ...getThemeStyles()
      }}
    >
      <div 
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: '12px'
        }}
      >
        <div 
          style={{
            width: '40px',
            height: '40px',
            borderRadius: '50%',
            background: 'rgba(255, 255, 255, 0.2)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '20px'
          }}
        >
          🤖
        </div>
        <div>
          <h3 
            style={{
              fontSize: '18px',
              fontWeight: '600',
              margin: '0',
              marginBottom: '2px'
            }}
          >
            AI Receptionist
          </h3>
          <span 
            style={{
              fontSize: '14px',
              opacity: '0.9'
            }}
          >
            Online
          </span>
        </div>
      </div>
      <div 
        style={{
          display: 'flex',
          gap: '8px'
        }}
      >
        {onToggleFAQs && (
          <button 
            style={{
              background: showFAQs ? 'rgba(255, 255, 255, 0.4)' : 'rgba(255, 255, 255, 0.2)',
              border: '0',
              color: 'white',
              width: '32px',
              height: '32px',
              borderRadius: '50%',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              transition: 'background 0.2s ease'
            }}
            onClick={onToggleFAQs}
            title="Frequently Asked Questions"
          >
            ❓
          </button>
        )}
        <button 
          style={{
            background: 'rgba(255, 255, 255, 0.2)',
            border: '0',
            color: 'white',
            width: '32px',
            height: '32px',
            borderRadius: '50%',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            transition: 'background 0.2s ease'
          }}
          onClick={onClose} 
          title="Close chat"
        >
          ✕
        </button>
      </div>
    </div>
  );
};

export default ChatHeader;