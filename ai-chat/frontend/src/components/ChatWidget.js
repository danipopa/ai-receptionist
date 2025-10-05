import React, { useState, useEffect, useRef } from 'react';
import ChatHeader from './ChatHeader';
import ChatMessages from './ChatMessages';
import ChatInput from './ChatInput';
import ChatToggle from './ChatToggle';
import FAQSuggestions from './FAQSuggestions';
import ApiService from '../services/ApiService';

const ChatWidget = ({ config }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [messages, setMessages] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  const [faqs, setFaqs] = useState([]);
  const [showFAQs, setShowFAQs] = useState(false);
  const [currentSession, setCurrentSession] = useState(null);
  const apiService = useRef(new ApiService(config.apiBaseUrl, config.apiKey));

  useEffect(() => {
    // Initialize welcome message
    if (isOpen && messages.length === 0) {
      setMessages([{
        id: Date.now(),
        text: config.welcomeMessage || 'Hi! How can I help you today?',
        isBot: true,
        timestamp: new Date()
      }]);
    }
  }, [isOpen, config.welcomeMessage, messages.length]);

  useEffect(() => {
    // Load FAQs if enabled
    if (config.enableFAQ && config.phoneNumberId) {
      loadFAQs();
    }
  }, [config.enableFAQ, config.phoneNumberId]);

  const loadFAQs = async () => {
    try {
      const faqData = await apiService.current.getFAQs(config.phoneNumberId);
      setFaqs(faqData);
    } catch (error) {
      console.error('Failed to load FAQs:', error);
    }
  };

  const createCallSession = async () => {
    if (!config.phoneNumberId) {
      console.warn('No phone number ID configured for call session');
      return null;
    }

    try {
      const callData = await apiService.current.createCall({
        phone_number_id: config.phoneNumberId,
        caller_phone: 'web-chat',
        status: 'in_progress',
        started_at: new Date().toISOString(),
        tags: ['web-chat', 'ai-receptionist']
      });
      return callData;
    } catch (error) {
      console.error('Failed to create call session:', error);
      return null;
    }
  };

  const addTranscript = async (content, speaker = 'user') => {
    if (!currentSession) return;

    try {
      await apiService.current.addTranscript(currentSession.id, {
        content,
        speaker,
        timestamp: new Date().toISOString(),
        confidence_score: 1.0,
        metadata: { source: 'web-chat' }
      });
    } catch (error) {
      console.error('Failed to add transcript:', error);
    }
  };

  const generateAIResponse = async (userMessage) => {
    try {
      // Use your Rails backend AI endpoint exclusively
      const response = await apiService.current.generateAIResponse(userMessage, {
        phoneNumberId: config.phoneNumberId,
        sessionId: currentSession?.id,
        conversationHistory: messages.slice(-10), // Last 10 messages for context
        customerId: currentSession?.customer_id,
        metadata: {
          source: 'web-chat',
          widget_config: {
            theme: config.theme,
            position: config.position
          }
        }
      });

      return response.message || response.response || response.data?.message || 'I apologize, but I\'m having trouble generating a response right now. Please try again.';
      
    } catch (error) {
      console.error('Backend AI response error:', error);
      
      // Simple fallback only if backend is completely unavailable
      return 'I\'m sorry, I\'m having trouble connecting to our AI service right now. Please try again in a moment, or I can connect you with a human agent.';
    }
  };

  const handleSendMessage = async (message) => {
    if (!message.trim()) return;

    // Add user message
    const userMessage = {
      id: Date.now(),
      text: message,
      isBot: false,
      timestamp: new Date()
    };
    setMessages(prev => [...prev, userMessage]);

    // Create call session if needed
    if (!currentSession) {
      const session = await createCallSession();
      setCurrentSession(session);
    }

    // Add to transcript
    await addTranscript(message, 'user');

    setIsLoading(true);

    try {
      // Add a small delay to make typing feel more natural
      await new Promise(resolve => setTimeout(resolve, 500 + Math.random() * 1000));
      
      // Generate AI response
      const aiResponse = await generateAIResponse(message);
      
      // Add bot response
      const botMessage = {
        id: Date.now() + 1,
        text: aiResponse,
        isBot: true,
        timestamp: new Date()
      };
      setMessages(prev => [...prev, botMessage]);

      // Add AI response to transcript
      await addTranscript(aiResponse, 'agent');

    } catch (error) {
      console.error('Failed to generate response:', error);
      const errorMessage = {
        id: Date.now() + 1,
        text: 'Sorry, I\'m having trouble responding right now. Please try again or contact our support team.',
        isBot: true,
        timestamp: new Date(),
        isError: true
      };
      setMessages(prev => [...prev, errorMessage]);
    }

    setIsLoading(false);
  };

  const handleFAQSelect = (faq) => {
    const faqMessage = {
      id: Date.now(),
      text: faq.question,
      isBot: false,
      timestamp: new Date()
    };
    
    const answerMessage = {
      id: Date.now() + 1,
      text: faq.answer,
      isBot: true,
      timestamp: new Date()
    };

    setMessages(prev => [...prev, faqMessage, answerMessage]);
    setShowFAQs(false);
  };

  const toggleChat = () => {
    setIsOpen(!isOpen);
    if (!isOpen) {
      setShowFAQs(false);
    }
  };

  const toggleFAQs = () => {
    setShowFAQs(!showFAQs);
  };

  return (
    <div 
      className={`chat-widget ${config.position} theme-${config.theme}`}
      style={{
        position: 'fixed',
        zIndex: 10000,
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", "Roboto", "Oxygen", "Ubuntu", "Cantarell", sans-serif',
        ...(config.position === 'bottom-right' && { bottom: '20px', right: '20px' }),
        ...(config.position === 'bottom-left' && { bottom: '20px', left: '20px' }),
        ...(config.position === 'top-right' && { top: '20px', right: '20px' }),
        ...(config.position === 'top-left' && { top: '20px', left: '20px' }),
      }}
    >
      {isOpen && (
        <div 
          className="chat-window"
          style={{
            width: '350px',
            height: '500px',
            backgroundColor: 'white',
            borderRadius: '12px',
            boxShadow: '0 8px 30px rgba(0, 0, 0, 0.15)',
            display: 'flex',
            flexDirection: 'column',
            overflow: 'hidden',
            marginBottom: '12px',
            border: '1px solid #e5e7eb',
            animation: 'slideUp 0.3s ease-out'
          }}
        >
          <ChatHeader 
            onClose={() => setIsOpen(false)}
            onToggleFAQs={config.enableFAQ ? toggleFAQs : null}
            showFAQs={showFAQs}
            theme={config.theme}
          />
          
          {showFAQs ? (
            <FAQSuggestions 
              faqs={faqs}
              onSelectFAQ={handleFAQSelect}
              onClose={() => setShowFAQs(false)}
            />
          ) : (
            <>
              <ChatMessages 
                messages={messages}
                isLoading={isLoading}
                theme={config.theme}
              />
              <ChatInput 
                onSendMessage={handleSendMessage}
                placeholder={config.placeholder}
                disabled={isLoading}
                theme={config.theme}
              />
            </>
          )}
        </div>
      )}
      
      <ChatToggle 
        isOpen={isOpen}
        onClick={toggleChat}
        theme={config.theme}
      />
    </div>
  );
};

export default ChatWidget;