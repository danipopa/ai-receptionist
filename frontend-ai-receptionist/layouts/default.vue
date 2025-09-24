<template>
  <div class="min-h-screen bg-gray-50">
    <!-- Navigation -->
    <nav class="bg-white shadow-sm border-b">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <div class="flex items-center">
            <h1 class="text-xl font-semibold text-gray-900">
              AI Receptionist Dashboard
            </h1>
          </div>
          
          <div class="flex items-center space-x-4">
            <NuxtLink
              to="/"
              class="text-gray-600 hover:text-gray-900 px-3 py-2 rounded-md text-sm font-medium"
              active-class="text-blue-600 bg-blue-50"
            >
              Dashboard
            </NuxtLink>
            <NuxtLink
              to="/customers"
              class="text-gray-600 hover:text-gray-900 px-3 py-2 rounded-md text-sm font-medium"
              active-class="text-blue-600 bg-blue-50"
            >
              Customers
            </NuxtLink>
            <NuxtLink
              to="/calls"
              class="text-gray-600 hover:text-gray-900 px-3 py-2 rounded-md text-sm font-medium"
              active-class="text-blue-600 bg-blue-50"
            >
              Calls
            </NuxtLink>
            <NuxtLink
              to="/analytics"
              class="text-gray-600 hover:text-gray-900 px-3 py-2 rounded-md text-sm font-medium"
              active-class="text-blue-600 bg-blue-50"
            >
              Analytics
            </NuxtLink>
          </div>
        </div>
      </div>
    </nav>
    
    <!-- Main content -->
    <main class="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
      <slot />
    </main>
  </div>
</template>