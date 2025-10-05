import axios from 'axios';

class ApiService {
  constructor(baseURL, apiKey = null) {
    this.apiKey = apiKey;
    this.client = axios.create({
      baseURL,
      headers: {
        'Content-Type': 'application/json',
        ...(apiKey && { 'Authorization': `Bearer ${apiKey}` }),
        ...(apiKey && { 'X-API-Key': apiKey })
      },
    });

    // Add response interceptor for error handling
    this.client.interceptors.response.use(
      (response) => response,
      (error) => {
        console.error('API Error:', error);
        throw error;
      }
    );
  }

  // Health check
  async checkHealth() {
    const response = await this.client.get('/health');
    return response.data;
  }

  // FAQ operations
  async getFAQs(phoneNumberId = null) {
    const url = phoneNumberId 
      ? `/phone_numbers/${phoneNumberId}/faqs`
      : '/faqs';
    const response = await this.client.get(url);
    return response.data.data || response.data;
  }

  async getFAQ(id) {
    const response = await this.client.get(`/faqs/${id}`);
    return response.data.data || response.data;
  }

  // Call operations (for chat sessions)
  async createCall(callData) {
    const response = await this.client.post('/calls', {
      call: callData
    });
    return response.data.data || response.data;
  }

  async updateCall(id, callData) {
    const response = await this.client.patch(`/calls/${id}`, {
      call: callData
    });
    return response.data.data || response.data;
  }

  async getCall(id) {
    const response = await this.client.get(`/calls/${id}`);
    return response.data.data || response.data;
  }

  // Transcript operations
  async addTranscript(callId, transcriptData) {
    const response = await this.client.post(`/calls/${callId}/transcript`, {
      transcript: transcriptData
    });
    return response.data.data || response.data;
  }

  async getTranscript(callId) {
    const response = await this.client.get(`/calls/${callId}/transcript`);
    return response.data.data || response.data;
  }

  // Customer operations
  async getCustomers(page = 1) {
    const response = await this.client.get(`/customers?page=${page}`);
    return response.data;
  }

  async getCustomer(id) {
    const response = await this.client.get(`/customers/${id}`);
    return response.data.data || response.data;
  }

  async createCustomer(customerData) {
    const response = await this.client.post('/customers', {
      customer: customerData
    });
    return response.data.data || response.data;
  }

  // Phone number operations
  async getPhoneNumbers() {
    const response = await this.client.get('/phone_numbers');
    return response.data.data || response.data;
  }

  async getPhoneNumber(id) {
    const response = await this.client.get(`/phone_numbers/${id}`);
    return response.data.data || response.data;
  }

  // Analytics
  async getAnalytics() {
    const response = await this.client.get('/analytics');
    return response.data;
  }

  async getCallAnalytics(startDate, endDate) {
    const params = new URLSearchParams();
    if (startDate) params.append('start_date', startDate);
    if (endDate) params.append('end_date', endDate);
    
    const response = await this.client.get(`/analytics/calls?${params}`);
    return response.data;
  }

  // AI Chat - Generate response using backend AI
  async generateAIResponse(message, context = {}) {
    try {
      const response = await this.client.post('/ai/chat', {
        message,
        phone_number_id: context.phoneNumberId,
        session_id: context.sessionId,
        context: {
          conversation_history: context.conversationHistory || [],
          customer_id: context.customerId,
          metadata: context.metadata || {}
        }
      });
      return response.data;
    } catch (error) {
      console.error('Error generating AI response:', error);
      throw error;
    }
  }

  // AI Responses (existing endpoints)
  async getAIResponses() {
    const response = await this.client.get('/ai_responses');
    return response.data.data || response.data;
  }

  async getAIResponse(id) {
    const response = await this.client.get(`/ai_responses/${id}`);
    return response.data.data || response.data;
  }

  // Search functionality (if needed)
  async searchFAQs(query, phoneNumberId = null) {
    try {
      const faqs = await this.getFAQs(phoneNumberId);
      return faqs.filter(faq => 
        faq.question.toLowerCase().includes(query.toLowerCase()) ||
        faq.answer.toLowerCase().includes(query.toLowerCase()) ||
        (faq.category && faq.category.toLowerCase().includes(query.toLowerCase()))
      );
    } catch (error) {
      console.error('Error searching FAQs:', error);
      return [];
    }
  }
}

export default ApiService;