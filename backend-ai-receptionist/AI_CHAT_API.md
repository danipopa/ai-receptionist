# AI Chat Endpoint Documentation

## Overview

The AI Chat endpoint provides a conversational interface for your AI receptionist, allowing frontend applications to send messages and receive intelligent responses.

## Endpoint

```
POST /api/v1/ai/chat
```

## Authentication

The endpoint requires API key authentication via either:
- `Authorization: Bearer {api_key}` header
- `X-API-Key: {api_key}` header

Set your API key in the environment:
```bash
export API_KEY=your-secret-api-key
```

## Request Format

```json
{
  "message": "User's question or statement",
  "phone_number_id": 123,
  "session_id": "unique_session_identifier", // Optional, will be generated if not provided
  "context": {
    "conversation_history": [
      { "role": "user", "message": "Previous user message" },
      { "role": "assistant", "message": "Previous AI response" }
    ],
    "customer_id": 456, // Optional
    "metadata": {} // Optional additional context
  }
}
```

## Response Format

```json
{
  "response": "AI generated response text",
  "session_id": "session_identifier",
  "status": "success"
}
```

## Error Responses

### Authentication Error (401)
```json
{
  "message": "Authentication failed",
  "error": "Invalid or missing API key"
}
```

### Validation Error (400)
```json
{
  "error": "Message is required",
  "status": "error"
}
```

### Not Found Error (404)
```json
{
  "error": "Phone number not found",
  "status": "error"
}
```

### Server Error (500)
```json
{
  "response": "I apologize, but I'm experiencing technical difficulties. Please try again.",
  "session_id": "session_identifier",
  "status": "error"
}
```

## AI Context Integration

The AI system automatically includes:

1. **Business Information**: Business name, hours, description
2. **FAQ Integration**: Relevant FAQs for the phone number
3. **Customer History**: Previous interactions if customer_id provided
4. **Conversation Context**: Full conversation history for natural flow

## AI Provider Configuration

Configure which AI provider to use via environment variables:

```bash
# Use Kubernetes-deployed Ollama (recommended)
AI_PROVIDER=kubernetes-ollama
OLLAMA_URL=http://ollama-service.ai-services.svc.cluster.local:11434
OLLAMA_TEXT_MODEL=llama2:7b

# Use Google Gemini (external API)
AI_PROVIDER=gemini
GOOGLE_API_KEY=your_gemini_api_key

# Use Hugging Face (external API)
AI_PROVIDER=huggingface
HUGGINGFACE_API_KEY=your_hf_api_key

# Use original implementation
AI_PROVIDER=original
AI_ENGINE_URL=http://your-ai-engine:8081
```

## Usage Examples

### Basic Chat
```bash
curl -X POST http://localhost:3000/api/v1/ai/chat \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What are your business hours?",
    "phone_number_id": 1
  }'
```

### Conversation with History
```bash
curl -X POST http://localhost:3000/api/v1/ai/chat \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Can I schedule an appointment?",
    "phone_number_id": 1,
    "session_id": "web_chat_12345",
    "context": {
      "conversation_history": [
        { "role": "user", "message": "What are your business hours?" },
        { "role": "assistant", "message": "We are open Monday through Friday, 9 AM to 5 PM." }
      ],
      "customer_id": 42
    }
  }'
```

### JavaScript/TypeScript Example
```typescript
const chatWithAI = async (message: string, sessionId?: string) => {
  const response = await fetch('/api/v1/ai/chat', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${API_KEY}`,
    },
    body: JSON.stringify({
      message,
      phone_number_id: phoneNumberId,
      session_id: sessionId,
      context: {
        conversation_history: conversationHistory,
        customer_id: customerId,
        metadata: { source: 'web_chat' }
      }
    })
  });
  
  return await response.json();
};
```

## Session Management

- **Session IDs** are automatically generated if not provided
- **Sessions persist** conversation context across multiple requests
- **Sessions are stored** as Call records in the database for tracking
- **Format**: `web_chat_{timestamp}_{random_hex}`

## Data Storage

Each chat conversation:
- Creates a `Call` record with type "chat"
- Stores individual messages as `CallMessage` records
- Links to customer and phone number for context
- Maintains conversation history for future reference

## Testing

Use the provided test script:

```bash
# Set your API key
export API_KEY=your-secret-api-key

# Run the test
ruby test_ai_chat.rb
```

## Integration Notes

1. **Phone Number Setup**: Ensure phone numbers exist in your database with proper business information and FAQs
2. **Customer Linking**: Provide customer_id for personalized responses
3. **FAQ Management**: Keep FAQs updated for better AI responses
4. **Session Persistence**: Use consistent session_ids for conversation continuity
5. **Error Handling**: Always handle potential errors and provide fallback responses

## Performance Considerations

- **Response Time**: Varies by AI provider (local Ollama ~2-5s, APIs ~1-3s)
- **Rate Limiting**: Consider implementing rate limiting for production use
- **Caching**: FAQ and business info are loaded per request (consider caching)
- **Concurrent Requests**: AI providers handle one request at a time per instance

## Security

- **API Keys**: Store securely and rotate regularly
- **Input Validation**: All inputs are validated and sanitized
- **PII Handling**: Customer data is handled according to your privacy policy
- **Audit Trail**: All conversations are logged in the database