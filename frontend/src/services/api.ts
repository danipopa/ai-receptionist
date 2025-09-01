import axios from 'axios';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';

// Create axios instance with default config
const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor for auth tokens (when implemented)
api.interceptors.request.use(
  (config) => {
    // Add auth token if available
    const token = localStorage.getItem('auth_token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor for error handling
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Handle unauthorized access
      localStorage.removeItem('auth_token');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export const apiService = {
  // Health check
  async getHealth() {
    const response = await api.get('/health');
    return response.data;
  },

  // Business management
  async getBusinesses() {
    try {
      const response = await api.get('/businesses');
      return response.data;
    } catch (error) {
      console.warn('API call failed, using temporary mock response:', error);
      // Return businesses stored in localStorage as temporary solution
      const storedBusinesses = localStorage.getItem('temp_businesses');
      return storedBusinesses ? JSON.parse(storedBusinesses) : [];
    }
  },

  async createBusiness(businessData: any) {
    try {
      const response = await api.post('/businesses', businessData);
      return response.data;
    } catch (error) {
      console.warn('API call failed, using temporary mock response:', error);
      // Temporary mock response until backend is deployed
      const newBusiness = {
        id: Date.now(),
        name: businessData.name,
        phone: businessData.phone_number || '',
        industry: businessData.industry || '',
        welcome_message: businessData.welcome_message || '',
        status: 'active',
        created_at: new Date().toISOString()
      };
      
      // Store in localStorage temporarily
      const storedBusinesses = localStorage.getItem('temp_businesses');
      const businesses = storedBusinesses ? JSON.parse(storedBusinesses) : [];
      businesses.push(newBusiness);
      localStorage.setItem('temp_businesses', JSON.stringify(businesses));
      
      return newBusiness;
    }
  },

  async updateBusiness(businessId: string, businessData: any) {
    try {
      const response = await api.put(`/businesses/${businessId}`, businessData);
      return response.data;
    } catch (error) {
      console.warn('API call failed, using temporary localStorage fallback:', error);
      // Update business in localStorage temporarily
      const storedBusinesses = localStorage.getItem('temp_businesses');
      if (storedBusinesses) {
        const businesses = JSON.parse(storedBusinesses);
        const businessIndex = businesses.findIndex((b: any) => b.id == businessId);
        if (businessIndex !== -1) {
          businesses[businessIndex] = {
            ...businesses[businessIndex],
            name: businessData.name,
            phone: businessData.phone_number || '',
            industry: businessData.industry || '',
            welcome_message: businessData.welcome_message || '',
            // Keep existing id, status, and created_at
          };
          localStorage.setItem('temp_businesses', JSON.stringify(businesses));
          return businesses[businessIndex];
        }
      }
      throw new Error('Business not found');
    }
  },

  async deleteBusiness(businessId: string) {
    const response = await api.delete(`/businesses/${businessId}`);
    return response.data;
  },

  // Call management
  async getBusinessCalls(businessId: string, limit = 100) {
    const response = await api.get(`/businesses/${businessId}/calls?limit=${limit}`);
    return response.data;
  },

  async getAllCalls(limit = 100) {
    const response = await api.get(`/calls?limit=${limit}`);
    return response.data;
  },

  async getCallDetails(callId: string) {
    const response = await api.get(`/calls/${callId}`);
    return response.data;
  },

  // Live call monitoring
  async getActiveCalls() {
    const response = await api.get('/calls/active');
    return response.data;
  },

  async endCall(callId: string) {
    const response = await api.post(`/call/${callId}/end`);
    return response.data;
  },

  // Analytics
  async getBusinessAnalytics(businessId: string, timeRange = '24h') {
    const response = await api.get(`/businesses/${businessId}/analytics?range=${timeRange}`);
    return response.data;
  },

  async getSystemAnalytics(timeRange = '24h') {
    const response = await api.get(`/analytics?range=${timeRange}`);
    return response.data;
  },

  // Receptionist configuration
  async getReceptionists(businessId: string) {
    const response = await api.get(`/businesses/${businessId}/receptionists`);
    return response.data;
  },

  async createReceptionist(businessId: string, receptionistData: any) {
    const response = await api.post(`/businesses/${businessId}/receptionists`, receptionistData);
    return response.data;
  },

  async updateReceptionist(businessId: string, receptionistId: string, receptionistData: any) {
    const response = await api.put(`/businesses/${businessId}/receptionists/${receptionistId}`, receptionistData);
    return response.data;
  },

  // Business configuration
  async getBusinessConfig(businessId: string) {
    const response = await api.get(`/businesses/${businessId}/config`);
    return response.data;
  },

  async updateBusinessConfig(businessId: string, config: any) {
    const response = await api.put(`/businesses/${businessId}/config`, config);
    return response.data;
  },

  // TTS and AI configuration
  async getAvailableVoices() {
    const response = await api.get('/tts/voices');
    return response.data;
  },

  async getAvailableModels() {
    const response = await api.get('/ai/models');
    return response.data;
  },

  async testVoice(text: string, voiceConfig: any) {
    const response = await api.post('/tts/test', { text, voice_config: voiceConfig }, { responseType: 'blob' });
    return response.data;
  },

  // File uploads
  async uploadAudio(file: File, callId?: string) {
    const formData = new FormData();
    formData.append('audio', file);
    if (callId) {
      formData.append('call_id', callId);
    }

    const response = await api.post('/upload/audio', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
    return response.data;
  },

  // WebSocket for real-time updates
  createWebSocket(callId?: string) {
    const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${wsProtocol}//${window.location.host}/ws${callId ? `/call/${callId}/stream` : '/events'}`;
    return new WebSocket(wsUrl);
  },
};

export default api;
