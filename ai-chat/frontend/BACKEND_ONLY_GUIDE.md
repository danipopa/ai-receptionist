# AI Chat Widget - Backend Only Integration

## 🎯 **Simple Backend Integration**

This chat widget now uses **only your Rails backend** with API key authentication. No external AI services needed.

## 🔧 **Setup**

### **1. Frontend Configuration**
```javascript
window.initChatWidget({
  apiBaseUrl: 'http://localhost:3000/api/v1',
  apiKey: 'your-backend-api-key',
  phoneNumberId: 'your-phone-number-id',
  position: 'bottom-right',
  theme: 'blue',
  welcomeMessage: 'Hi! How can I help you today?'
});
```

### **2. Backend Endpoint Required**
Your Rails backend needs this endpoint:

```ruby
# routes.rb
namespace :api do
  namespace :v1 do
    namespace :ai do
      post 'chat', to: 'chat#generate_response'
    end
  end
end
```

```ruby
# app/controllers/api/v1/ai/chat_controller.rb
class Api::V1::Ai::ChatController < ApplicationController
  before_action :authenticate_api_key
  
  def generate_response
    message = params[:message]
    phone_number_id = params[:phone_number_id]
    session_id = params[:session_id]
    context = params[:context] || {}
    
    # Your AI logic here
    response = generate_ai_response(message, context)
    
    render json: { 
      message: response,
      status: 'success'
    }
  end
  
  private
  
  def authenticate_api_key
    api_key = request.headers['X-API-Key'] || request.headers['Authorization']&.remove('Bearer ')
    
    unless valid_api_key?(api_key)
      render json: { error: 'Invalid API key' }, status: 401
    end
  end
  
  def valid_api_key?(key)
    # Your API key validation logic
    key == ENV['CHAT_WIDGET_API_KEY']
  end
  
  def generate_ai_response(message, context)
    # Your AI response generation logic
    # This could use:
    # - OpenAI API
    # - Local AI model
    # - Rule-based responses
    # - Database lookup
    
    "Response to: #{message}"
  end
end
```

## 📡 **API Request Format**

The widget sends this to your backend:

```json
POST /api/v1/ai/chat
Headers: {
  "X-API-Key": "your-api-key",
  "Content-Type": "application/json"
}
Body: {
  "message": "User's message",
  "phone_number_id": "123",
  "session_id": "session-456",
  "context": {
    "conversation_history": [
      {"text": "Previous message", "isBot": false, "timestamp": "..."},
      {"text": "Previous response", "isBot": true, "timestamp": "..."}
    ],
    "customer_id": "789",
    "metadata": {
      "source": "web-chat",
      "widget_config": {
        "theme": "blue",
        "position": "bottom-right"
      }
    }
  }
}
```

## 🔒 **Security**

- **API Key Authentication**: All requests require valid API key
- **Headers**: Supports both `X-API-Key` and `Authorization: Bearer` formats
- **Validation**: Backend validates API key before processing

## 🎨 **Features**

- ✅ **Backend AI Only**: No external dependencies
- ✅ **API Key Security**: Authenticated requests
- ✅ **Conversation Context**: Sends chat history
- ✅ **Session Tracking**: Links to call sessions
- ✅ **FAQ Integration**: Still uses your FAQ database
- ✅ **Error Handling**: Graceful fallbacks

## 📝 **Example Backend AI Implementation**

```ruby
def generate_ai_response(message, context)
  conversation_history = context['conversation_history'] || []
  phone_number_id = context['phone_number_id']
  
  # 1. Check FAQs first
  faq_response = check_faqs(message, phone_number_id)
  return faq_response if faq_response
  
  # 2. Use your AI service (OpenAI, etc.)
  if ENV['OPENAI_API_KEY']
    return call_openai(message, conversation_history)
  end
  
  # 3. Rule-based fallback
  return rule_based_response(message)
end

private

def check_faqs(message, phone_number_id)
  # Search your FAQ database
  faqs = Faq.where(phone_number_id: phone_number_id)
  faq = faqs.find { |f| message.downcase.include?(f.question.downcase.split(' ').first) }
  faq&.answer
end

def call_openai(message, history)
  # Your OpenAI integration
  # Build context from history and send to OpenAI
end

def rule_based_response(message)
  case message.downcase
  when /hours?|open|close/
    "Our business hours are Monday-Friday, 9 AM to 5 PM EST."
  when /contact|phone|email/
    "You can contact us at support@yourcompany.com or call us at (555) 123-4567."
  else
    "I understand you have a question. Let me connect you with a human agent who can help."
  end
end
```

## 🚀 **Benefits**

- ✅ **Full Control**: Your backend handles all AI logic
- ✅ **Security**: API key authentication
- ✅ **Flexibility**: Use any AI service in your backend
- ✅ **Privacy**: All data stays on your servers
- ✅ **Cost Control**: Manage AI costs in your backend
- ✅ **Scalability**: Scale according to your needs

This approach gives you complete control while keeping the frontend simple and secure!