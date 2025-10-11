<template>
  <div>
    <!-- Header -->
    <div class="flex items-center mb-8">
      <button @click="$router.back()" class="mr-4 text-gray-500 hover:text-gray-700">
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"></path>
        </svg>
      </button>
      <div v-if="customer">
        <h2 class="text-2xl font-bold text-gray-900">{{ customer.name }}</h2>
        <p class="text-gray-600">{{ customer.email }}</p>
      </div>
      <div v-else-if="loading" class="flex items-center">
        <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600 mr-3"></div>
        <span class="text-gray-600">Loading customer...</span>
      </div>
    </div>

    <!-- Error State -->
    <div v-if="error" class="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
      <p class="text-red-600">{{ error }}</p>
      <button 
        @click="fetchCustomer" 
        class="mt-2 bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded"
      >
        Try Again
      </button>
    </div>

    <!-- Main Content -->
    <div v-if="customer" class="space-y-8">
      <!-- Incoming Numbers Section -->
      <div class="bg-white shadow rounded-lg">
        <div class="px-6 py-4 border-b border-gray-200 flex justify-between items-center">
          <div>
            <h3 class="text-lg font-medium text-gray-900">Incoming Phone Numbers</h3>
            <p class="text-sm text-gray-600">Manage phone numbers for this customer</p>
          </div>
          <button
            @click="showAddNumberModal = true"
            class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-medium"
          >
            Add Number
          </button>
        </div>
        
        <div class="p-6">
          <div v-if="incomingNumbers.length === 0" class="text-center py-8">
            <p class="text-gray-500">No phone numbers configured yet.</p>
          </div>
          
          <div v-else class="space-y-3">
            <div
              v-for="number in incomingNumbers"
              :key="number.id"
              class="border border-gray-200 rounded-lg p-4"
            >
              <div class="flex items-start justify-between">
                <div class="flex-1">
                  <div class="flex items-center space-x-3">
                    <p class="font-medium text-gray-900">{{ number.number }}</p>
                    <span
                      v-if="number.is_primary"
                      class="px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800"
                    >
                      Primary
                    </span>
                  </div>
                  
                  <p class="text-sm text-gray-600 mt-1">{{ number.description || 'No description' }}</p>
                  
                  <!-- SIP Trunk Status -->
                  <div class="mt-2 flex items-center space-x-4">
                    <span
                      :class="[
                        'px-2 py-1 text-xs rounded-full',
                        number.sip_trunk_enabled ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'
                      ]"
                    >
                      {{ number.sip_trunk_enabled ? 'SIP Enabled' : 'SIP Disabled' }}
                    </span>
                    
                    <span
                      v-if="number.sip_trunk_enabled"
                      :class="[
                        'px-2 py-1 text-xs rounded-full',
                        number.connection_mode === 'trunk' ? 'bg-purple-100 text-purple-800' : 'bg-orange-100 text-orange-800'
                      ]"
                    >
                      {{ number.connection_mode === 'trunk' ? 'Direct Trunk' : 'Registration' }}
                    </span>
                    
                    <span
                      v-if="number.sip_trunk_enabled && number.incoming_calls_enabled"
                      class="px-2 py-1 text-xs rounded-full bg-green-100 text-green-800"
                    >
                      Incoming ✓
                    </span>
                    
                    <span
                      v-if="number.sip_trunk_enabled && number.outbound_calls_enabled"
                      class="px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800"
                    >
                      Outbound ✓
                    </span>
                  </div>
                  
                  <!-- SIP Details -->
                  <div v-if="number.sip_trunk_enabled" class="mt-2 text-xs text-gray-500">
                    <span v-if="number.sip_trunk_host">{{ number.sip_trunk_host }}:{{ number.sip_trunk_port || 5060 }}</span>
                    <span v-if="number.sip_trunk_protocol" class="ml-2">({{ number.sip_trunk_protocol }})</span>
                  </div>
                </div>
                
                <div class="flex items-center space-x-2">
                  <button
                    v-if="number.sip_trunk_enabled"
                    @click="testSipTrunk(number)"
                    class="text-green-600 hover:text-green-800 text-sm"
                  >
                    Test SIP
                  </button>
                  <button
                    @click="editNumber(number)"
                    class="text-blue-600 hover:text-blue-800 text-sm"
                  >
                    Edit
                  </button>
                  <button
                    @click="removeNumber(number.id)"
                    class="text-red-600 hover:text-red-800 text-sm"
                  >
                    Remove
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Website Settings Section -->
      <div class="bg-white shadow rounded-lg">
        <div class="px-6 py-4 border-b border-gray-200">
          <h3 class="text-lg font-medium text-gray-900">Website Settings</h3>
          <p class="text-sm text-gray-600">Configure website URL and related settings</p>
        </div>
        
        <div class="p-6">
          <form @submit.prevent="updateWebsiteSettings" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700">Website URL</label>
              <input
                v-model="websiteSettings.url"
                type="url"
                placeholder="https://example.com"
                class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 px-3 py-2"
              >
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700">Description</label>
              <textarea
                v-model="websiteSettings.description"
                rows="3"
                placeholder="Brief description of the website or business"
                class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 px-3 py-2"
              ></textarea>
            </div>
            
            <div class="flex items-center">
              <input
                v-model="websiteSettings.enabled"
                type="checkbox"
                class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              >
              <label class="ml-2 block text-sm text-gray-900">
                Enable website integration
              </label>
            </div>
            
            <button
              type="submit"
              :disabled="updatingWebsite"
              class="bg-blue-600 hover:bg-blue-700 disabled:bg-blue-400 text-white px-4 py-2 rounded-lg font-medium"
            >
              {{ updatingWebsite ? 'Updating...' : 'Update Website Settings' }}
            </button>
          </form>
        </div>
      </div>

      <!-- FAQ Section -->
      <div class="bg-white shadow rounded-lg">
        <div class="px-6 py-4 border-b border-gray-200 flex justify-between items-center">
          <div>
            <h3 class="text-lg font-medium text-gray-900">FAQ Management</h3>
            <p class="text-sm text-gray-600">Manage frequently asked questions for the AI assistant</p>
          </div>
          <button
            @click="addFaqItem"
            class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-medium"
          >
            Add FAQ Item
          </button>
        </div>
        
        <div class="p-6">
          <div v-if="faqItems.length === 0" class="text-center py-8">
            <p class="text-gray-500">No FAQ items configured yet.</p>
          </div>
          
          <div v-else class="space-y-4">
            <div
              v-for="(item, index) in faqItems"
              :key="index"
              class="border border-gray-200 rounded-lg p-4"
            >
              <div class="space-y-3">
                <div>
                  <label class="block text-sm font-medium text-gray-700">Question</label>
                  <input
                    v-model="item.question"
                    type="text"
                    placeholder="Enter the question"
                    class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 px-3 py-2"
                  >
                </div>
                
                <div>
                  <label class="block text-sm font-medium text-gray-700">Answer</label>
                  <textarea
                    v-model="item.answer"
                    rows="3"
                    placeholder="Enter the answer"
                    class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 px-3 py-2"
                  ></textarea>
                </div>
                
                <div class="flex items-center justify-between">
                  <div class="flex items-center">
                    <input
                      v-model="item.active"
                      type="checkbox"
                      class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                    >
                    <label class="ml-2 block text-sm text-gray-900">
                      Active
                    </label>
                  </div>
                  <button
                    @click="removeFaqItem(index)"
                    class="text-red-600 hover:text-red-800 text-sm"
                  >
                    Remove
                  </button>
                </div>
              </div>
            </div>
          </div>
          
          <div v-if="faqItems.length > 0" class="mt-6 pt-4 border-t border-gray-200">
            <button
              @click="updateFaqSettings"
              :disabled="updatingFaq"
              class="bg-blue-600 hover:bg-blue-700 disabled:bg-blue-400 text-white px-4 py-2 rounded-lg font-medium"
            >
              {{ updatingFaq ? 'Updating...' : 'Update FAQ Settings' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Add Number Modal -->
    <div v-if="showAddNumberModal" class="fixed inset-0 bg-gray-600 bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg shadow-xl max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
        <div class="px-6 py-4 border-b border-gray-200">
          <h3 class="text-lg font-medium text-gray-900">Add Phone Number & SIP Configuration</h3>
        </div>
        
        <form @submit.prevent="addNumber" class="p-6 space-y-6">
          <!-- Basic Phone Number Info -->
          <div class="space-y-4">
            <h4 class="text-md font-medium text-gray-900">Phone Number Details</h4>
            
            <div>
              <label class="block text-sm font-medium text-gray-700">Phone Number</label>
              <input
                v-model="newNumber.number"
                type="tel"
                required
                placeholder="+1234567890"
                class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 px-3 py-2"
              >
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700">Description (Optional)</label>
              <input
                v-model="newNumber.description"
                type="text"
                placeholder="Main line, support, etc."
                class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 px-3 py-2"
              >
            </div>
          </div>

          <!-- SIP Configuration -->
          <div class="space-y-4 border-t border-gray-200 pt-6">
            <h4 class="text-md font-medium text-gray-900">SIP Trunk Configuration</h4>
            
            <div class="flex items-center">
              <input
                v-model="newNumber.sip_trunk_enabled"
                type="checkbox"
                class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              >
              <label class="ml-2 block text-sm text-gray-900">
                Enable SIP trunk for this number
              </label>
            </div>

            <div v-if="newNumber.sip_trunk_enabled" class="space-y-4 ml-6 pl-4 border-l-2 border-blue-200">
              <!-- Connection Mode -->
              <div>
                <label class="block text-sm font-medium text-gray-700">Connection Mode</label>
                <select
                  v-model="newNumber.connection_mode"
                  class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 px-3 py-2"
                >
                  <option value="trunk">Direct SIP Trunk (IP-based authentication)</option>
                  <option value="register">Outbound Registration (Username/Password)</option>
                </select>
                <p class="mt-1 text-xs text-gray-500">
                  <span v-if="newNumber.connection_mode === 'trunk'">
                    Your SIP provider sends calls directly to our IP address. No registration needed.
                  </span>
                  <span v-else>
                    Our system registers to your SIP server using provided credentials.
                  </span>
                </p>
              </div>

              <!-- SIP Host & Port -->
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700">SIP Host</label>
                  <input
                    v-model="newNumber.sip_trunk_host"
                    type="text"
                    required
                    placeholder="sip.provider.com"
                    class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 px-3 py-2"
                  >
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Port</label>
                  <input
                    v-model.number="newNumber.sip_trunk_port"
                    type="number"
                    min="1"
                    max="65535"
                    placeholder="5060"
                    class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 px-3 py-2"
                  >
                </div>
              </div>

              <!-- Conditional fields based on connection mode -->
              <div v-if="newNumber.connection_mode === 'register'" class="space-y-4">
                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Username</label>
                    <input
                      v-model="newNumber.sip_trunk_username"
                      type="text"
                      required
                      placeholder="Your SIP username"
                      class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 px-3 py-2"
                    >
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Password</label>
                    <input
                      v-model="newNumber.sip_trunk_password"
                      type="password"
                      required
                      placeholder="Your SIP password"
                      class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 px-3 py-2"
                    >
                  </div>
                </div>
              </div>

              <div v-if="newNumber.connection_mode === 'trunk' || newNumber.connection_mode === 'register'">
                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Domain</label>
                    <input
                      v-model="newNumber.sip_trunk_domain"
                      type="text"
                      :required="newNumber.connection_mode === 'trunk'"
                      placeholder="provider.com"
                      class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 px-3 py-2"
                    >
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Protocol</label>
                    <select
                      v-model="newNumber.sip_trunk_protocol"
                      class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 px-3 py-2"
                    >
                      <option value="UDP">UDP</option>
                      <option value="TCP">TCP</option>
                      <option value="TLS">TLS</option>
                    </select>
                  </div>
                </div>
              </div>

              <!-- Call Direction Settings -->
              <div class="space-y-2">
                <div class="flex items-center">
                  <input
                    v-model="newNumber.incoming_calls_enabled"
                    type="checkbox"
                    class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                  >
                  <label class="ml-2 block text-sm text-gray-900">
                    Enable incoming calls (AI will answer)
                  </label>
                </div>
                <div class="flex items-center">
                  <input
                    v-model="newNumber.outbound_calls_enabled"
                    type="checkbox"
                    class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                  >
                  <label class="ml-2 block text-sm text-gray-900">
                    Enable outbound calls (for AI to make calls)
                  </label>
                </div>
              </div>
            </div>
          </div>
          
          <div v-if="addNumberError" class="p-3 bg-red-50 border border-red-200 rounded-md">
            <p class="text-sm text-red-600">{{ addNumberError }}</p>
          </div>
          
          <div class="flex justify-end space-x-3">
            <button
              type="button"
              @click="closeAddNumberModal"
              class="px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              :disabled="addingNumber"
              class="bg-blue-600 hover:bg-blue-700 disabled:bg-blue-400 text-white px-4 py-2 rounded-md"
            >
              {{ addingNumber ? 'Adding...' : 'Add Number' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup>
const route = useRoute()
const router = useRouter()
const config = useRuntimeConfig()

// Customer data
const customer = ref(null)
const loading = ref(true)
const error = ref(null)

// Incoming numbers
const incomingNumbers = ref([])
const showAddNumberModal = ref(false)
const addingNumber = ref(false)
const addNumberError = ref(null)
const newNumber = ref({
  number: '',
  description: '',
  is_primary: false,
  sip_trunk_enabled: false,
  connection_mode: 'trunk',
  sip_trunk_host: '',
  sip_trunk_port: 5060,
  sip_trunk_username: '',
  sip_trunk_password: '',
  sip_trunk_domain: '',
  sip_trunk_protocol: 'UDP',
  incoming_calls_enabled: true,
  outbound_calls_enabled: false
})

// Website settings
const websiteSettings = ref({
  url: '',
  description: '',
  enabled: true
})
const updatingWebsite = ref(false)

// FAQ settings
const faqItems = ref([])
const updatingFaq = ref(false)

// Get customer ID from route
const customerId = computed(() => route.params.id)

// Fetch customer data
const fetchCustomer = async () => {
  try {
    loading.value = true
    error.value = null
    
    const response = await $fetch(`${config.public.apiBase}/customers/${customerId.value}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${config.public.apiKey}`
      }
    })
    
    customer.value = response.data
    
    // Load related data
    await Promise.all([
      fetchIncomingNumbers(),
      fetchWebsiteSettings(),
      fetchFaqSettings()
    ])
    
  } catch (err) {
    console.error('Failed to fetch customer:', err)
    error.value = err.data?.message || err.message || 'Failed to load customer'
  } finally {
    loading.value = false
  }
}

// Fetch incoming numbers
const fetchIncomingNumbers = async () => {
  try {
    const response = await $fetch(`${config.public.apiBase}/customers/${customerId.value}/numbers`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${config.public.apiKey}`
      }
    })
    
    incomingNumbers.value = response.data || []
  } catch (err) {
    console.error('Failed to fetch incoming numbers:', err)
    // Don't show error for this, just use empty array
    incomingNumbers.value = []
  }
}

// Fetch website settings
const fetchWebsiteSettings = async () => {
  try {
    const response = await $fetch(`${config.public.apiBase}/customers/${customerId.value}/website`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${config.public.apiKey}`
      }
    })
    
    if (response.data) {
      websiteSettings.value = { ...websiteSettings.value, ...response.data }
    }
  } catch (err) {
    console.error('Failed to fetch website settings:', err)
    // Don't show error, use defaults
  }
}

// Fetch FAQ settings
const fetchFaqSettings = async () => {
  try {
    const response = await $fetch(`${config.public.apiBase}/customers/${customerId.value}/faq`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${config.public.apiKey}`
      }
    })
    
    faqItems.value = response.data || []
  } catch (err) {
    console.error('Failed to fetch FAQ settings:', err)
    // Don't show error, use empty array
    faqItems.value = []
  }
}

// Add new phone number
const addNumber = async () => {
  try {
    addingNumber.value = true
    addNumberError.value = null
    
    const response = await $fetch(`${config.public.apiBase}/customers/${customerId.value}/numbers`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${config.public.apiKey}`
      },
      body: {
        phone_number: newNumber.value
      }
    })
    
    incomingNumbers.value.push(response.data)
    closeAddNumberModal()
    
  } catch (err) {
    console.error('Failed to add number:', err)
    addNumberError.value = err.data?.message || err.message || 'Failed to add phone number'
  } finally {
    addingNumber.value = false
  }
}

// Remove phone number
const removeNumber = async (numberId) => {
  if (!confirm('Are you sure you want to remove this phone number?')) return
  
  try {
    await $fetch(`${config.public.apiBase}/customers/${customerId.value}/numbers/${numberId}`, {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${config.public.apiKey}`
      }
    })
    
    incomingNumbers.value = incomingNumbers.value.filter(n => n.id !== numberId)
    
  } catch (err) {
    console.error('Failed to remove number:', err)
  }
}

// Update website settings
const updateWebsiteSettings = async () => {
  try {
    updatingWebsite.value = true
    
    await $fetch(`${config.public.apiBase}/customers/${customerId.value}/website`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${config.public.apiKey}`
      },
      body: {
        website: websiteSettings.value
      }
    })
    
    // Show success message or toast here
    
  } catch (err) {
    console.error('Failed to update website settings:', err)
  } finally {
    updatingWebsite.value = false
  }
}

// Add FAQ item
const addFaqItem = () => {
  faqItems.value.push({
    question: '',
    answer: '',
    active: true
  })
}

// Remove FAQ item
const removeFaqItem = (index) => {
  faqItems.value.splice(index, 1)
}

// Update FAQ settings
const updateFaqSettings = async () => {
  try {
    updatingFaq.value = true
    
    await $fetch(`${config.public.apiBase}/customers/${customerId.value}/faq`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${config.public.apiKey}`
      },
      body: {
        faq_items: faqItems.value
      }
    })
    
    // Show success message or toast here
    
  } catch (err) {
    console.error('Failed to update FAQ settings:', err)
  } finally {
    updatingFaq.value = false
  }
}

// Test SIP trunk connection
const testSipTrunk = async (number) => {
  try {
    const response = await $fetch(`${config.public.apiBase}/customers/${customerId.value}/phone_numbers/${number.id}/test_sip_trunk`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${config.public.apiKey}`
      }
    })
    
    // Show success/error message
    if (response.status === 'success') {
      alert(`SIP Test Successful!\nMode: ${response.mode}\n${response.message}`)
    } else {
      alert(`SIP Test Failed: ${response.message}`)
    }
    
  } catch (err) {
    console.error('Failed to test SIP trunk:', err)
    alert('Failed to test SIP trunk connection')
  }
}

// Edit phone number (placeholder for now)
const editNumber = (number) => {
  // For now, just show an alert. In a real implementation, you'd open an edit modal
  alert(`Edit functionality for ${number.number} will be implemented soon`)
}

// Modal functions
const closeAddNumberModal = () => {
  showAddNumberModal.value = false
  addNumberError.value = null
  newNumber.value = {
    number: '',
    description: '',
    is_primary: false,
    sip_trunk_enabled: false,
    connection_mode: 'trunk',
    sip_trunk_host: '',
    sip_trunk_port: 5060,
    sip_trunk_username: '',
    sip_trunk_password: '',
    sip_trunk_domain: '',
    sip_trunk_protocol: 'UDP',
    incoming_calls_enabled: true,
    outbound_calls_enabled: false
  }
}

// Load customer data on mount
onMounted(() => {
  fetchCustomer()
})
</script>