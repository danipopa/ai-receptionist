<template>
  <div>
    <div class="flex justify-between items-center mb-8">
      <div>
        <h2 class="text-2xl font-bold text-gray-900">Customers</h2>
        <p class="text-gray-600">Manage your customers and their phone numbers</p>
      </div>
      <button
        @click="showCreateModal = true"
        class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-medium"
      >
        Add Customer
      </button>
    </div>
    
    <!-- Customer List -->
    <div class="bg-white shadow rounded-lg">
      <div class="px-6 py-4 border-b border-gray-200">
        <h3 class="text-lg font-medium text-gray-900">All Customers</h3>
      </div>
      
      <div v-if="loading" class="p-8 text-center">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
        <p class="mt-2 text-gray-600">Loading customers...</p>
      </div>
      
      <div v-else-if="error" class="p-8 text-center">
        <p class="text-red-600">{{ error }}</p>
        <button 
          @click="fetchCustomers" 
          class="mt-2 bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded"
        >
          Try Again
        </button>
      </div>
      
      <div v-else-if="customers.length === 0" class="p-8 text-center">
        <p class="text-gray-500">No customers found. Add your first customer to get started.</p>
      </div>
      
      <div v-else class="divide-y divide-gray-200">
        <div
          v-for="customer in customers"
          :key="customer.id"
          class="p-6 hover:bg-gray-50 cursor-pointer"
          @click="navigateToCustomer(customer.id)"
        >
          <div class="flex items-center justify-between">
            <div class="flex-1">
              <div class="flex items-center">
                <div class="flex-shrink-0 h-10 w-10">
                  <div class="h-10 w-10 rounded-full bg-blue-500 flex items-center justify-center">
                    <span class="text-white font-medium text-sm">
                      {{ customer.name.charAt(0).toUpperCase() }}
                    </span>
                  </div>
                </div>
                <div class="ml-4">
                  <div class="text-sm font-medium text-gray-900">{{ customer.name }}</div>
                  <div class="text-sm text-gray-500">{{ customer.email }}</div>
                  <div v-if="customer.company" class="text-sm text-gray-500">{{ customer.company }}</div>
                </div>
              </div>
            </div>
            
            <div class="flex items-center space-x-4">
              <div class="text-sm text-gray-500">
                {{ customer.phone_numbers_count || 0 }} number{{ (customer.phone_numbers_count || 0) !== 1 ? 's' : '' }}
              </div>
              <span
                :class="customer.active ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'"
                class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
              >
                {{ customer.active ? 'Active' : 'Inactive' }}
              </span>
              <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Create Customer Modal -->
    <div v-if="showCreateModal" class="fixed inset-0 bg-gray-600 bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg p-6 w-full max-w-md">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Add New Customer</h3>
        
        <form @submit.prevent="createCustomer">
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700">Name</label>
              <input
                v-model="newCustomer.name"
                type="text"
                required
                class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 px-3 py-2"
              >
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700">Email</label>
              <input
                v-model="newCustomer.email"
                type="email"
                required
                class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 px-3 py-2"
              >
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700">Company (Optional)</label>
              <input
                v-model="newCustomer.company"
                type="text"
                class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 px-3 py-2"
              >
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700">Phone (Optional)</label>
              <input
                v-model="newCustomer.phone"
                type="tel"
                class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 px-3 py-2"
              />
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700">Address (Optional)</label>
              <textarea
                v-model="newCustomer.address"
                rows="2"
                class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 px-3 py-2"
              ></textarea>
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700">Notes (Optional)</label>
              <textarea
                v-model="newCustomer.notes"
                rows="3"
                class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 px-3 py-2"
              ></textarea>
            </div>
          </div>
          
          <div v-if="createError" class="mt-4 p-3 bg-red-50 border border-red-200 rounded-md">
            <p class="text-sm text-red-600">{{ createError }}</p>
          </div>
          
          <div class="mt-6 flex justify-end space-x-3">
            <button
              type="button"
              @click="closeModal"
              class="px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              :disabled="creating"
              class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
            >
              {{ creating ? 'Creating...' : 'Create Customer' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
interface Customer {
  id: number
  name: string
  email: string
  company?: string
  description?: string
  active: boolean
  phone_numbers_count: number
  created_at: string
  updated_at: string
}

// Reactive data
const customers = ref<Customer[]>([])
const loading = ref(true)
const error = ref<string | null>(null)
const showCreateModal = ref(false)
const creating = ref(false)
const createError = ref<string | null>(null)

const newCustomer = ref({
  name: '',
  email: '',
  company: '',
  phone: '',
  address: '',
  notes: ''
})

// Get runtime config
const config = useRuntimeConfig()

// API calls using $fetch properly
const fetchCustomers = async () => {
  try {
    loading.value = true
    error.value = null
    
    const response = await $fetch(`${config.public.apiBase}/customers`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${config.public.apiKey}`
      }
    })
    
    customers.value = response.data || []
  } catch (err: any) {
    console.error('Failed to fetch customers:', err)
    error.value = err.data?.message || err.message || 'Failed to load customers. Please check if the backend is running.'
  } finally {
    loading.value = false
  }
}

const createCustomer = async () => {
  try {
    creating.value = true
    createError.value = null
    
    const response = await $fetch(`${config.public.apiBase}/customers`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${config.public.apiKey}`
      },
      body: { 
        customer: newCustomer.value 
      }
    })
    
    customers.value.unshift(response.data)
    closeModal()
  } catch (err: any) {
    console.error('Failed to create customer:', err)
    createError.value = err.data?.message || err.message || 'Failed to create customer'
  } finally {
    creating.value = false
  }
}

const closeModal = () => {
  showCreateModal.value = false
  createError.value = null
  resetForm()
}

const resetForm = () => {
  newCustomer.value = {
    name: '',
    email: '',
    company: '',
    phone: '',
    address: '',
    notes: ''
  }
}

const navigateToCustomer = (id: number) => {
  navigateTo(`/customers/${id}`)
}

// Load customers on mount
onMounted(() => {
  fetchCustomers()
})
</script>