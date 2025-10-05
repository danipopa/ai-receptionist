import React from 'react';
import ReactDOM from 'react-dom/client';
import ChatWidget from './components/ChatWidget';
import './styles/tailwind.css';
import './styles/global.css';

// Main initialization function for the widget
function initChatWidget(config = {}) {
  const defaultConfig = {
    // Backend API Configuration
    apiBaseUrl: 'https://api.frontmind.mobiletel.eu/api/v1',
    apiKey: '', // Your Rails backend API key
    phoneNumberId: null, // Should be provided by the website
    
    // UI Configuration
    position: 'bottom-right',
    theme: 'blue',
    welcomeMessage: 'Hi! How can I help you today?',
    placeholder: 'Type your message...',
    enableFAQ: true,
    enableHumanHandoff: true
  };

  const finalConfig = { ...defaultConfig, ...config };

  // Create widget container if it doesn't exist
  let container = document.getElementById('ai-chat-widget');
  if (!container) {
    container = document.createElement('div');
    container.id = 'ai-chat-widget';
    document.body.appendChild(container);
  }

  // Render the widget
  const root = ReactDOM.createRoot(container);
  root.render(<ChatWidget config={finalConfig} />);

  return {
    destroy: () => {
      root.unmount();
      if (container.parentNode) {
        container.parentNode.removeChild(container);
      }
    },
    updateConfig: (newConfig) => {
      root.render(<ChatWidget config={{ ...finalConfig, ...newConfig }} />);
    }
  };
}

// Auto-initialize if config is provided via data attributes
document.addEventListener('DOMContentLoaded', () => {
  const scriptTag = document.querySelector('script[data-ai-chat-widget]');
  if (scriptTag) {
    const config = {
      apiBaseUrl: scriptTag.getAttribute('data-api-url') || 'https://api.frontmind.mobiletel.eu/api/v1',
      phoneNumberId: scriptTag.getAttribute('data-phone-number-id'),
      theme: scriptTag.getAttribute('data-theme') || 'blue',
      welcomeMessage: scriptTag.getAttribute('data-welcome-message'),
      enableFAQ: scriptTag.getAttribute('data-enable-faq') !== 'false'
    };
    
    initChatWidget(config);
  }
});

// For demo purposes, auto-initialize with default config
if (process.env.NODE_ENV === 'development') {
  initChatWidget();
}

// Export for manual initialization
window.AIChatWidget = { init: initChatWidget };

export default initChatWidget;