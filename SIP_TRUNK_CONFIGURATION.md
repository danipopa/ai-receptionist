# Customer SIP Trunk Configuration Guide

## 🎯 **Overview**
Your AI Receptionist system now supports **customer-managed SIP trunk configuration**. Each customer can configure their own incoming SIP trunk with phone number mapping, allowing FreeSWITCH to authenticate and route calls automatically.

## 🔧 **How It Works**

### **For Customers:**
1. **Configure SIP Trunk**: Set up their SIP provider details (host, credentials, protocol)
2. **Map Phone Numbers**: Associate incoming phone numbers with their SIP trunk
3. **Test Connection**: Verify SIP trunk connectivity before going live
4. **Auto-Authentication**: FreeSWITCH automatically authenticates based on their configuration

### **For FreeSWITCH:**
1. **Directory Lookup**: Authenticates SIP registration attempts using customer credentials
2. **Gateway Configuration**: Routes outbound calls through customer's SIP trunk
3. **Dialplan Routing**: Routes incoming calls to customer's phone numbers to AI receptionist
4. **Multi-Tenant Isolation**: Each customer's calls are isolated and secure

## 📋 **API Endpoints for Customer SIP Configuration**

### **Get Customer SIP Configuration**
```http
GET /api/v1/customers/{id}/sip_configuration
Authorization: Bearer YOUR_API_KEY
```

**Response:**
```json
{
  "data": {
    "customer_id": 1,
    "customer_name": "ACME Corp",
    "sip_enabled": true,
    "sip_username": "acme",
    "sip_domain": "ai-receptionist.local",
    "sip_uri": "sip:acme@ai-receptionist.local",
    "max_concurrent_calls": 5,
    "phone_numbers": [
      {
        "id": 1,
        "number": "+15551234567",
        "sip_trunk_enabled": true,
        "sip_trunk_host": "sip.provider.com",
        "sip_trunk_port": 5060,
        "sip_trunk_username": "acme_trunk",
        "sip_trunk_domain": "provider.com",
        "sip_trunk_protocol": "UDP",
        "incoming_calls_enabled": true,
        "outbound_calls_enabled": false
      }
    ]
  }
}
```

### **Configure SIP Trunk for Phone Number**
```http
POST /api/v1/customers/{id}/phone_numbers/{phone_number_id}/configure_sip_trunk
Authorization: Bearer YOUR_API_KEY
Content-Type: application/json

{
  "phone_number": {
    "sip_trunk_enabled": true,
    "sip_trunk_host": "sip.provider.com",
    "sip_trunk_port": 5060,
    "sip_trunk_username": "your_username",
    "sip_trunk_password": "your_password",
    "sip_trunk_domain": "provider.com",
    "sip_trunk_protocol": "UDP",
    "incoming_calls_enabled": true,
    "outbound_calls_enabled": false
  }
}
```

### **Test SIP Trunk Connection**
```http
POST /api/v1/customers/{id}/phone_numbers/{phone_number_id}/test_sip_trunk
Authorization: Bearer YOUR_API_KEY
```

### **Get FreeSWITCH Configuration**
```http
GET /api/v1/customers/{id}/freeswitch_config
Authorization: Bearer YOUR_API_KEY
```

## 🔧 **FreeSWITCH Integration Endpoints**

### **Directory Authentication**
```http
POST /api/v1/freeswitch/directory
Content-Type: application/x-www-form-urlencoded

domain=provider.com&user=acme_trunk
```

### **Dialplan Routing**
```http
POST /api/v1/freeswitch/dialplan
Content-Type: application/x-www-form-urlencoded

Caller-Destination-Number=+15551234567
```

### **Gateway Configuration**
```http
POST /api/v1/freeswitch/configuration
Content-Type: application/x-www-form-urlencoded

section=sofia.conf
```

## 🛡️ **Security & Authentication Flow**

### **Customer Authentication**
1. Customer SIP device registers with FreeSWITCH
2. FreeSWITCH queries: `POST /api/v1/freeswitch/directory`
3. Backend returns XML with customer-specific authentication
4. FreeSWITCH validates credentials and allows/denies connection

### **Incoming Call Flow**
1. Call comes in to customer's phone number
2. FreeSWITCH queries: `POST /api/v1/freeswitch/dialplan`
3. Backend returns XML routing to AI receptionist
4. Call is processed by AI with customer context

### **Multi-Tenant Isolation**
- Each customer has unique SIP credentials
- Phone numbers are mapped to specific customers
- Calls are isolated by customer context
- Billing and analytics are customer-specific

## 💡 **Example Customer Configuration**

### **Step 1: Get Customer SIP Info**
```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  https://api.frontmind.mobiletel.eu/api/v1/customers/1/sip_configuration
```

### **Step 2: Configure SIP Trunk**
```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "phone_number": {
      "sip_trunk_enabled": true,
      "sip_trunk_host": "sip.twilio.com",
      "sip_trunk_port": 5060,
      "sip_trunk_username": "ACf1234567890abcdef",
      "sip_trunk_password": "your_auth_token",
      "sip_trunk_domain": "twilio.com",
      "sip_trunk_protocol": "UDP",
      "incoming_calls_enabled": true
    }
  }' \
  https://api.frontmind.mobiletel.eu/api/v1/customers/1/phone_numbers/1/configure_sip_trunk
```

### **Step 3: Test Connection**
```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_API_KEY" \
  https://api.frontmind.mobiletel.eu/api/v1/customers/1/phone_numbers/1/test_sip_trunk
```

## 📊 **Database Schema**

### **New Phone Number Fields**
- `sip_trunk_enabled` - Enable/disable SIP trunk for this number
- `sip_trunk_host` - SIP provider hostname
- `sip_trunk_port` - SIP provider port (default: 5060)
- `sip_trunk_username` - SIP authentication username
- `sip_trunk_password` - SIP authentication password
- `sip_trunk_domain` - SIP domain/realm
- `sip_trunk_protocol` - Protocol (UDP/TCP/TLS)
- `sip_trunk_context` - FreeSWITCH context (default: ai_receptionist)
- `incoming_calls_enabled` - Allow incoming calls
- `outbound_calls_enabled` - Allow outbound calls

## 🚀 **Next Steps**

1. **Run Database Migration**:
   ```bash
   bundle exec rails db:migrate
   ```

2. **Update Docker Images**:
   ```bash
   docker build -t 176.9.65.80:5000/ai-receptionist/backend-ai-receptionist:latest .
   docker push 176.9.65.80:5000/ai-receptionist/backend-ai-receptionist:latest
   ```

3. **Deploy to Kubernetes**:
   ```bash
   kubectl apply -f k8s-manifests/backend/
   ```

4. **Configure FreeSWITCH**:
   - Set XML curl endpoints to your backend API
   - Enable directory, dialplan, and configuration lookups

Your customers can now **self-configure their SIP trunks** through the customer interface! 🎉