import React from 'react';

const ChatToggle = ({ isOpen, onClick, theme }) => {
  const getThemeClasses = () => {
    switch (theme) {
      case 'green':
        return 'bg-gradient-to-br from-green-400 to-green-600 hover:from-green-500 hover:to-green-700';
      case 'purple':
        return 'bg-gradient-to-br from-purple-400 to-purple-600 hover:from-purple-500 hover:to-purple-700';
      default:
        return 'bg-gradient-to-br from-blue-500 to-blue-700 hover:from-blue-600 hover:to-blue-800';
    }
  };

  return (
    <button
      className={`
        w-16 h-16 rounded-full border-0 cursor-pointer 
        flex items-center justify-center shadow-lg 
        transition-all duration-300 text-white
        hover:scale-105 hover:shadow-xl
        ${getThemeClasses()}
        ${isOpen ? 'rotate-45' : ''}
      `}
      style={{
        // Fallback styles to ensure button is always visible
        width: '64px',
        height: '64px',
        borderRadius: '50%',
        border: '0',
        cursor: 'pointer',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
        color: 'white',
        boxShadow: '0 8px 30px rgba(0, 0, 0, 0.15)',
        transition: 'all 0.3s ease',
        transform: isOpen ? 'rotate(45deg)' : 'rotate(0deg)'
      }}
      onClick={onClick}
      title={isOpen ? 'Close chat' : 'Open chat'}
    >
      {isOpen ? (
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
          <path
            d="M18 6L6 18M6 6L18 18"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      ) : (
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
          <path
            d="M21 11.5C21.0034 12.8199 20.6951 14.1219 20.1 15.3C19.3944 16.7118 18.3098 17.8992 16.9674 18.7293C15.6251 19.5594 14.0782 19.9994 12.5 20C11.1801 20.0035 9.87812 19.6951 8.7 19.1L3 21L4.9 15.3C4.30493 14.1219 3.99656 12.8199 4 11.5C4.00061 9.92179 4.44061 8.37488 5.27072 7.03258C6.10083 5.69028 7.28825 4.60571 8.7 3.90003C9.87812 3.30496 11.1801 2.99659 12.5 3.00003H13C15.0843 3.11502 17.053 3.99479 18.5291 5.47089C20.0052 6.94699 20.885 8.91568 21 11V11.5Z"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      )}
    </button>
  );
};

export default ChatToggle;