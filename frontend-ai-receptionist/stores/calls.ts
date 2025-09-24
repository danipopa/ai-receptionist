import { defineStore } from 'pinia'

interface Call {
  id: string
  phone_number: string
  status: string
  started_at: string
  ended_at?: string
  duration?: number
  summary?: string
}

export const useCallsStore = defineStore('calls', () => {
  const calls = ref<Call[]>([])
  const currentCall = ref<Call | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)
  
  const { getCalls, getCall } = useApi()
  
  const fetchCalls = async () => {
    loading.value = true
    error.value = null
    
    try {
      const response = await getCalls()
      calls.value = response.data || response
    } catch (err) {
      error.value = 'Failed to fetch calls'
      console.error(err)
    } finally {
      loading.value = false
    }
  }
  
  const fetchCall = async (id: string) => {
    loading.value = true
    error.value = null
    
    try {
      const response = await getCall(id)
      currentCall.value = response.data || response
    } catch (err) {
      error.value = 'Failed to fetch call'
      console.error(err)
    } finally {
      loading.value = false
    }
  }
  
  return {
    calls,
    currentCall,
    loading,
    error,
    fetchCalls,
    fetchCall
  }
})