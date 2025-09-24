// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  devtools: { enabled: true },

  // Disable TypeScript checking to avoid vue-tsc issues
  typescript: {
    typeCheck: false
  },

  // Remove any database-related configurations
  nitro: {
    // Remove any database configurations
    experimental: {
      wasm: false
    }
  },

  // API configuration for backend communication
  runtimeConfig: {
    public: {
      apiBase: process.env.API_BASE_URL || 'http://localhost:3000/api/v1',
      apiHost: process.env.API_HOST || 'localhost',
      apiPort: process.env.API_PORT || '3000'
    }
  },

  // CSS framework
  css: ['~/assets/css/main.css'],

  // Modules (remove any database-related modules)
  modules: [
    '@nuxtjs/tailwindcss',
    '@pinia/nuxt'
  ],

  // Vite configuration to avoid checker issues
  vite: {
    vue: {
      script: {
        defineModel: true,
        propsDestructure: true
      }
    }
  }
})