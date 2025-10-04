# Backend AI Receptionist - API Documentation

Base URL: `http://YOUR_SERVER:PORT/api/v1`

All endpoints return JSON responses.

---

## 🔍 Health & Status

### Get API Health
```bash
GET /api/v1/health
```

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2025-10-04T12:00:00Z"
}
```

---

## 👥 Customers

### List All Customers
```bash
GET /api/v1/customers?page=1
```

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "name": "John Doe",
      "email": "john@example.com",
      "company": "Acme Corp",
      "phone": "+1234567890",
      "address": "123 Main St",
      "notes": "VIP customer",
      "phone_numbers_count": 2,
      "created_at": "2025-01-01T00:00:00Z",
      "updated_at": "2025-01-01T00:00:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 5,
    "total_count": 100
  }
}
```

### Get Single Customer
```bash
GET /api/v1/customers/:id
```

**Response:**
```json
{
  "data": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "company": "Acme Corp",
    "phone": "+1234567890",
    "address": "123 Main St",
    "notes": "VIP customer",
    "phone_numbers_count": 2,
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-01T00:00:00Z",
    "phone_numbers": [
      {
        "id": 1,
        "number": "+1234567890",
        "formatted_number": "+1 (234) 567-890",
        "display_name": "Main Office",
        "description": "Primary contact number",
        "is_primary": true,
        "faqs_count": 5,
        "call_transcripts_count": 10
      }
    ]
  }
}
```

### Create Customer
```bash
POST /api/v1/customers
Content-Type: application/json

{
  "customer": {
    "name": "John Doe",
    "email": "john@example.com",
    "company": "Acme Corp",
    "phone": "+1234567890",
    "address": "123 Main St",
    "notes": "VIP customer"
  }
}
```

**Response (201 Created):**
```json
{
  "data": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    ...
  }
}
```

### Update Customer
```bash
PATCH /api/v1/customers/:id
Content-Type: application/json

{
  "customer": {
    "name": "Jane Doe",
    "email": "jane@example.com"
  }
}
```

### Delete Customer (Soft Delete)
```bash
DELETE /api/v1/customers/:id
```

**Response:** `204 No Content`

---

## 📞 Phone Numbers

### List All Phone Numbers
```bash
GET /api/v1/phone_numbers
```

### Get Phone Number
```bash
GET /api/v1/phone_numbers/:id
```

### Create Phone Number for Customer
```bash
POST /api/v1/customers/:customer_id/phone_numbers
Content-Type: application/json

{
  "phone_number": {
    "number": "+1234567890",
    "display_name": "Main Office",
    "description": "Primary contact",
    "is_primary": true
  }
}
```

### Update Phone Number
```bash
PATCH /api/v1/phone_numbers/:id
Content-Type: application/json

{
  "phone_number": {
    "display_name": "Updated Name"
  }
}
```

### Delete Phone Number
```bash
DELETE /api/v1/phone_numbers/:id
```

---

## 📞 Calls

### List All Calls
```bash
GET /api/v1/calls?page=1
```

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "caller_phone": "+1234567890",
      "status": "completed",
      "duration": "5m 30s",
      "summary": "Customer inquired about pricing",
      "sentiment": "positive",
      "tags": ["pricing", "inquiry"],
      "started_at": "2025-10-04T10:00:00Z",
      "ended_at": "2025-10-04T10:05:30Z",
      "phone_number": {
        "id": 1,
        "number": "+1234567890",
        "label": "Support Line"
      },
      "customer": {
        "id": 1,
        "name": "John Doe"
      }
    }
  ],
  "meta": {
    "current_page": 1,
    "total_pages": 10,
    "total_count": 200
  }
}
```

### Get Single Call
```bash
GET /api/v1/calls/:id
```

### Create Call
```bash
POST /api/v1/calls
Content-Type: application/json

{
  "call": {
    "phone_number_id": 1,
    "caller_phone": "+1234567890",
    "status": "in_progress",
    "started_at": "2025-10-04T10:00:00Z",
    "tags": ["support"]
  }
}
```

### Update Call
```bash
PATCH /api/v1/calls/:id
Content-Type: application/json

{
  "call": {
    "status": "completed",
    "ended_at": "2025-10-04T10:05:30Z",
    "summary": "Issue resolved",
    "sentiment": "positive"
  }
}
```

### Get Call Transcript
```bash
GET /api/v1/calls/:id/transcript
```

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "content": "Hello, how can I help you?",
      "speaker": "agent",
      "timestamp": "2025-10-04T10:00:00Z",
      "confidence_score": 0.95,
      "metadata": {}
    },
    {
      "id": 2,
      "content": "I have a question about pricing",
      "speaker": "caller",
      "timestamp": "2025-10-04T10:00:05Z",
      "confidence_score": 0.92,
      "metadata": {}
    }
  ]
}
```

### Add Transcript to Call
```bash
POST /api/v1/calls/:id/transcript
Content-Type: application/json

{
  "transcript": {
    "content": "Thank you for calling",
    "speaker": "agent",
    "timestamp": "2025-10-04T10:05:00Z",
    "confidence_score": 0.98,
    "metadata": {}
  }
}
```

---

## ❓ FAQs

### List FAQs for Phone Number
```bash
GET /api/v1/phone_numbers/:phone_number_id/faqs
```

### List All FAQs
```bash
GET /api/v1/faqs
```

### Get FAQ
```bash
GET /api/v1/faqs/:id
```

### Create FAQ
```bash
POST /api/v1/faqs
Content-Type: application/json

{
  "faq": {
    "phone_number_id": 1,
    "question": "What are your business hours?",
    "answer": "We are open Monday-Friday, 9 AM to 5 PM",
    "category": "general",
    "priority": 1
  }
}
```

### Update FAQ
```bash
PATCH /api/v1/faqs/:id
Content-Type: application/json

{
  "faq": {
    "answer": "Updated answer"
  }
}
```

### Upload PDF to FAQ
```bash
POST /api/v1/faqs/:id/upload_pdf
Content-Type: multipart/form-data

file: <pdf_file>
```

### Delete FAQ
```bash
DELETE /api/v1/faqs/:id
```

---

## 🤖 AI Responses

### List AI Responses
```bash
GET /api/v1/ai_responses
```

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "call_id": 1,
      "prompt": "Customer asked about pricing",
      "response": "Our basic plan starts at $29/month",
      "model_used": "gpt-4",
      "tokens_used": 150,
      "response_time_ms": 450,
      "created_at": "2025-10-04T10:00:00Z"
    }
  ]
}
```

### Get Single AI Response
```bash
GET /api/v1/ai_responses/:id
```

---

## 📊 Analytics

### Get General Analytics
```bash
GET /api/v1/analytics
```

**Response:**
```json
{
  "total_calls": 1500,
  "total_customers": 250,
  "total_phone_numbers": 300,
  "avg_call_duration": "4m 30s",
  "sentiment_distribution": {
    "positive": 800,
    "neutral": 500,
    "negative": 200
  }
}
```

### Get Call Analytics
```bash
GET /api/v1/analytics/calls?start_date=2025-01-01&end_date=2025-12-31
```

### Get Customer Analytics
```bash
GET /api/v1/analytics/customers
```

---

## 🔄 Event Handling (External Services)

### Receive Call Events from FreeSWITCH
```bash
POST /api/calls/events
Content-Type: application/json

{
  "event_type": "call_started",
  "call_id": "abc123",
  "caller_phone": "+1234567890",
  "timestamp": "2025-10-04T10:00:00Z"
}
```

---

## 🏥 Service Health Checks

### Check AI Engine Health
```bash
GET /api/health/ai_engine
```

**Response:**
```json
{
  "status": "healthy",
  "response_time_ms": 50,
  "version": "1.0.0"
}
```

### Check FreeSWITCH Health
```bash
GET /api/health/freeswitch
```

### Check All Services Health
```bash
GET /api/health/all
```

**Response:**
```json
{
  "services": {
    "ai_engine": {
      "status": "healthy",
      "response_time_ms": 50
    },
    "freeswitch": {
      "status": "healthy",
      "response_time_ms": 25
    },
    "database": {
      "status": "healthy",
      "response_time_ms": 10
    }
  },
  "overall_status": "healthy"
}
```

---

## 📝 Error Responses

All error responses follow this format:

```json
{
  "errors": ["Error message 1", "Error message 2"],
  "message": "Human-readable error description"
}
```

**Common Status Codes:**
- `200 OK` - Success
- `201 Created` - Resource created successfully
- `204 No Content` - Success with no response body
- `400 Bad Request` - Invalid request parameters
- `404 Not Found` - Resource not found
- `422 Unprocessable Entity` - Validation errors
- `500 Internal Server Error` - Server error

---

## 🚀 Example Usage

### curl Examples

```bash
# Health check
curl http://localhost:3000/api/v1/health

# List customers
curl http://localhost:3000/api/v1/customers

# Create a customer
curl -X POST http://localhost:3000/api/v1/customers \
  -H "Content-Type: application/json" \
  -d '{
    "customer": {
      "name": "John Doe",
      "email": "john@example.com",
      "company": "Acme Corp"
    }
  }'

# Get a specific call with details
curl http://localhost:3000/api/v1/calls/1

# Add transcript to a call
curl -X POST http://localhost:3000/api/v1/calls/1/transcript \
  -H "Content-Type: application/json" \
  -d '{
    "transcript": {
      "content": "Hello, how can I help you?",
      "speaker": "agent",
      "timestamp": "2025-10-04T10:00:00Z"
    }
  }'
```

---

## 📋 Notes

- All timestamps are in ISO 8601 format (UTC)
- Pagination is available on list endpoints (use `?page=N`)
- Soft deletes are used for customers (they're marked inactive, not deleted)
- Phone numbers must be in E.164 format (e.g., +1234567890)
- Authentication/Authorization may be added in the future
