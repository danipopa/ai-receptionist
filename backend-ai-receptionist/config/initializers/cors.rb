# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Allow requests from Nuxt frontend (development and production)
    origins "http://localhost:3000", "http://localhost:3001", 
            "https://frontmind.mobiletel.eu", 
            "https://api.frontmind.mobiletel.eu"

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end

  # Allow AI services to communicate with backend
  allow do
    origins "http://localhost:8080", "http://localhost:8081",
            "http://ai-engine-service:8081", "http://freeswitch-integration-service:8080"

    resource "/api/*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
