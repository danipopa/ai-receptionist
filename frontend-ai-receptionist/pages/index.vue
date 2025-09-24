<template>
  <div>
    <div class="mb-8">
      <h2 class="text-2xl font-bold text-gray-900">Dashboard</h2>
      <p class="text-gray-600">Monitor your AI receptionist activity</p>
    </div>
    
    <!-- Status Cards -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
      <div class="bg-white p-6 rounded-lg shadow">
        <div class="flex items-center">
          <div class="p-2 bg-green-500 rounded-lg">
            <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"></path>
            </svg>
          </div>
          <div class="ml-4">
            <p class="text-sm font-medium text-gray-600">Active Calls</p>
            <p class="text-2xl font-semibold text-gray-900">{{ activeCalls }}</p>
          </div>
        </div>
      </div>
      
      <div class="bg-white p-6 rounded-lg shadow">
        <div class="flex items-center">
          <div class="p-2 bg-blue-500 rounded-lg">
            <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>
            </svg>
          </div>
          <div class="ml-4">
            <p class="text-sm font-medium text-gray-600">Today's Calls</p>
            <p class="text-2xl font-semibold text-gray-900">{{ todaysCalls }}</p>
          </div>
        </div>
      </div>
      
      <div class="bg-white p-6 rounded-lg shadow">
        <div class="flex items-center">
          <div class="p-2 bg-purple-500 rounded-lg">
            <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path>
            </svg>
          </div>
          <div class="ml-4">
            <p class="text-sm font-medium text-gray-600">AI Responses</p>
            <p class="text-2xl font-semibold text-gray-900">{{ aiResponses }}</p>
          </div>
        </div>
      </div>
      
      <div class="bg-white p-6 rounded-lg shadow">
        <div class="flex items-center">
          <div class="p-2 bg-yellow-500 rounded-lg">
            <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
          </div>
          <div class="ml-4">
            <p class="text-sm font-medium text-gray-600">Customers</p>
            <p class="text-2xl font-semibold text-gray-900">{{ totalCustomers }}</p>
          </div>
        </div>
      </div>
    </div>
    
    <!-- System Status -->
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="text-lg font-medium text-gray-900 mb-4">System Status</h3>
      <div class="space-y-3">
        <div class="flex items-center justify-between">
          <span class="text-sm text-gray-600">Backend API</span>
          <span :class="backendStatus.class">
            {{ backendStatus.text }}
          </span>
        </div>
        <div class="flex items-center justify-between">
          <span class="text-sm text-gray-600">AI Engine</span>
          <span :class="aiEngineStatus.class">
            {{ aiEngineStatus.text }}
          </span>
        </div>
        <div class="flex items-center justify-between">
          <span class="text-sm text-gray-600">FreeSWITCH</span>
          <span :class="freeswitchStatus.class">
            {{ freeswitchStatus.text }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
// Reactive data
const activeCalls = ref<number>(0)
const todaysCalls = ref<number>(0)
const aiResponses = ref<number>(0)
const totalCustomers = ref<number>(0)

// Status objects
const backendStatus = ref({
  text: 'Checking...',
  class: 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800'
})

const aiEngineStatus = ref({
  text: 'Checking...',
  class: 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800'
})

const freeswitchStatus = ref({
  text: 'Checking...',
  class: 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800'
})

// Status classes
const statusClasses = {
  online: 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800',
  offline: 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800',
  connecting: 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800'
}

const api = useApi()

// Check system status
const checkSystemStatus = async () => {
  // Check backend
  try {
    await api.healthCheck()
    backendStatus.value = { text: 'Online', class: statusClasses.online }
    
    // Load dashboard data
    await loadDashboardData()
  } catch (error) {
    console.error('Backend health check failed:', error)
    backendStatus.value = { text: 'Offline', class: statusClasses.offline }
  }
  
  // Check AI Engine
  try {
    const response = await fetch('http://localhost:8001/health')
    if (response.ok) {
      aiEngineStatus.value = { text: 'Online', class: statusClasses.online }
    } else {
      aiEngineStatus.value = { text: 'Offline', class: statusClasses.offline }
    }
  } catch (error) {
    console.error('AI Engine health check failed:', error)
    aiEngineStatus.value = { text: 'Offline', class: statusClasses.offline }
  }
  
  // Check FreeSWITCH
  try {
    const response = await fetch('http://localhost:8080/health')
    if (response.ok) {
      freeswitchStatus.value = { text: 'Online', class: statusClasses.online }
    } else {
      freeswitchStatus.value = { text: 'Connecting', class: statusClasses.connecting }
    }
  } catch (error) {
    console.error('FreeSWITCH health check failed:', error)
    freeswitchStatus.value = { text: 'Offline', class: statusClasses.offline }
  }
}

// Load dashboard data
const loadDashboardData = async () => {
  try {
    const response = await api.getDashboardData()
    activeCalls.value = response.activeCalls
    todaysCalls.value = response.todaysCalls
    aiResponses.value = response.aiResponses
    totalCustomers.value = response.totalCustomers
  } catch (error) {
    console.error('Failed to load dashboard data:', error)
  }
}

// Fetch dashboard data on mount
onMounted(async () => {
  await checkSystemStatus()
  
  // Set up periodic status checks
  setInterval(checkSystemStatus, 30000) // Check every 30 seconds
})
</script>