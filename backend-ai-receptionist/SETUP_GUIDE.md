# Quick Setup Guide for AI Chat API

## 1. Install Dependencies

```bash
# Install Ruby gems
bundle install

# The following gems will be installed for AI providers:
# - ruby-openai (for OpenAI-compatible APIs)
# - faraday (for HTTP clients)
# - faraday-multipart (for file uploads)
```

## 2. Set Environment Variables

```bash
# Copy the example environment file
cp .env.example .env

# Edit .env and set your values
# Required: API key for authentication
export API_KEY="your-secure-api-key-here"

# Optional: AI Provider configuration
export AI_PROVIDER="ollama"  # or "kubernetes-ollama", "gemini", "huggingface", "original"

# For Local Ollama (easiest for development)
export OLLAMA_URL="http://localhost:11434"
export OLLAMA_TEXT_MODEL="llama2"

# For Kubernetes Ollama
export OLLAMA_URL="http://ollama-service.ai-services.svc.cluster.local:11434"
export OLLAMA_TEXT_MODEL="llama2:7b"

# For Google Gemini
export GOOGLE_API_KEY="your-gemini-api-key"

# For Hugging Face
export HUGGINGFACE_API_KEY="your-hf-api-key"
```

## 3. Database Setup

Ensure you have at least one phone number record:

```ruby
# In Rails console
PhoneNumber.create!(
  number: '+1234567890',
  business_name: 'Your Business Name',
  business_hours: 'Monday-Friday, 9 AM - 5 PM',
  business_description: 'We provide excellent customer service...'
)

# Add some FAQs
phone_number = PhoneNumber.first
phone_number.faqs.create!([
  {
    question: 'What are your business hours?',
    answer: 'We are open Monday through Friday from 9 AM to 5 PM.'
  },
  {
    question: 'How can I schedule an appointment?',
    answer: 'You can schedule an appointment by calling us or using our online booking system.'
  }
])
```

## 4. Start Your Backend

```bash
cd backend-ai-receptionist
bundle install
rails server
```

## 5. Test the API

```bash
# Basic health check (no auth required)
curl http://localhost:3000/api/v1/health

# Test AI chat endpoint
curl -X POST http://localhost:3000/api/v1/ai/chat \
  -H "Authorization: Bearer your-secure-api-key-here" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello, what are your business hours?",
    "phone_number_id": 1
  }'
```

## 6. Frontend Integration

```javascript
// Example frontend integration
const API_BASE = 'http://localhost:3000/api/v1';
const API_KEY = 'your-secure-api-key-here';

async function sendMessage(message, sessionId = null) {
  try {
    const response = await fetch(`${API_BASE}/ai/chat`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${API_KEY}`,
      },
      body: JSON.stringify({
        message: message,
        phone_number_id: 1, // Replace with actual phone number ID
        session_id: sessionId,
        context: {
          conversation_history: getConversationHistory(),
          metadata: { source: 'web_chat' }
        }
      })
    });

    const data = await response.json();
    
    if (data.status === 'success') {
      return {
        response: data.response,
        sessionId: data.session_id
      };
    } else {
      throw new Error(data.error || 'Chat request failed');
    }
  } catch (error) {
    console.error('Chat error:', error);
    throw error;
  }
}

function getConversationHistory() {
  // Return array of { role: 'user'|'assistant', message: 'text' }
  return [];
}
```

## 7. Production Checklist

- [ ] Set secure API keys in production
- [ ] Deploy AI services (Ollama/etc) to Kubernetes
- [ ] Configure proper CORS settings
- [ ] Set up SSL/TLS certificates
- [ ] Configure rate limiting
- [ ] Set up monitoring and logging
- [ ] Test error handling scenarios
- [ ] Backup conversation data regularly

## Troubleshooting

### Authentication Issues
- Verify API_KEY environment variable is set
- Check that Authorization header is correctly formatted
- Ensure API key contains no extra spaces or newlines

### AI Provider Issues
- Check AI_PROVIDER environment variable
- Verify AI service is running and accessible
- Check service logs for connection errors

### Database Issues
- Ensure phone_number_id exists in database
- Check database connection
- Verify migrations are up to date

### Connection Issues
- Verify backend is running on correct port
- Check CORS configuration for frontend domain
- Ensure no firewall blocking requests

## Getting Help

1. Check the logs: `tail -f log/development.log`
2. Run the test script: `ruby test_ai_chat.rb`
3. Verify health endpoints: `curl http://localhost:3000/health`
4. Check AI provider specific documentation in `KUBERNETES_AI_DEPLOYMENT.md`