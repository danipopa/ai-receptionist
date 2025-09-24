export const useApi = () => {
  const config = useRuntimeConfig()
  
  const apiCall = async (endpoint: string, options: any = {}) => {
    try {
      const response = await $fetch(`${config.public.apiBase}${endpoint}`, {
        ...options,
        headers: {
          'Content-Type': 'application/json',
          ...options.headers
        }
      })
      return response
    } catch (error: any) {
      console.error('API call failed:', error)
      
      // Re-throw with better error messaging
      if (error.status === 500) {
        throw new Error('Server error. Please check if the backend is running.')
      } else if (error.status === 404) {
        throw new Error('Resource not found.')
      } else if (error.status === 422) {
        throw new Error(error.data?.message || 'Validation failed.')
      } else {
        throw new Error(error.data?.message || error.message || 'An unexpected error occurred.')
      }
    }
  }
  
  return {
    // Customer management
    getCustomers: () => apiCall('/customers'),
    getCustomer: (id: string) => apiCall(`/customers/${id}`),
    createCustomer: (data: any) => apiCall('/customers', { method: 'POST', body: data }),
    updateCustomer: (id: string, data: any) => apiCall(`/customers/${id}`, { method: 'PATCH', body: data }),
    deleteCustomer: (id: string) => apiCall(`/customers/${id}`, { method: 'DELETE' }),
    
    // Phone number management
    getPhoneNumbers: (customerId: string) => apiCall(`/customers/${customerId}/phone_numbers`),
    createPhoneNumber: (customerId: string, data: any) => apiCall(`/customers/${customerId}/phone_numbers`, { method: 'POST', body: data }),
    
    // Call management
    getCalls: () => apiCall('/calls'),
    getCall: (id: string) => apiCall(`/calls/${id}`),
    createCall: (data: any) => apiCall('/calls', { method: 'POST', body: data }),
    getCallTranscript: (id: string) => apiCall(`/calls/${id}/transcript`),
    
    // AI interactions
    getAiResponses: (callId: string) => apiCall(`/calls/${callId}/ai_responses`),
    
    // Analytics
    getAnalytics: () => apiCall('/analytics'),
    
    // Health check
    healthCheck: () => apiCall('/health')
  }
}