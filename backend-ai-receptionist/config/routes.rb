Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  
  # Kubernetes health check endpoints with database connectivity check
  get "health" => "health#health"
  get "ready" => "health#ready"

  # API routes
  namespace :api do
    namespace :v1 do
      # Health check
      get 'health', to: 'health#index'

      # Customers and their phone numbers
      resources :customers do
        resources :phone_numbers, except: [:index]
        
        # Customer-specific endpoints for frontend
        member do
          get 'numbers', to: 'customers#phone_numbers'
          post 'numbers', to: 'customers#create_phone_number'
          get 'website', to: 'customers#website_settings'
          put 'website', to: 'customers#update_website_settings'
          get 'faq', to: 'customers#faq_settings'
          put 'faq', to: 'customers#update_faq_settings'
          
          # SIP trunk configuration endpoints
          get 'sip_configuration', to: 'customers#sip_configuration'
          patch 'sip_configuration', to: 'customers#update_sip_configuration'
          get 'freeswitch_config', to: 'customers#freeswitch_config'
          
          # Phone number SIP trunk management
          post 'phone_numbers/:phone_number_id/configure_sip_trunk', to: 'customers#configure_sip_trunk'
          post 'phone_numbers/:phone_number_id/test_sip_trunk', to: 'customers#test_sip_trunk'
        end
        
        # Nested phone number management
        resources :phone_numbers, path: 'numbers', except: [:index] do
          member do
            put '', to: 'phone_numbers#update'
            delete '', to: 'phone_numbers#destroy'
          end
        end
      end

      # Phone numbers (can also be accessed directly)
      resources :phone_numbers do
        resources :faqs
        resources :calls, only: [:index]
      end

      # Calls with transcript functionality
      resources :calls do
        member do
          get :transcript
          post :transcript, action: :add_transcript
        end
      end

      # AI responses
      resources :ai_responses, only: [:index, :show]

      # FAQs with file upload
      resources :faqs do
        member do
          post :upload_pdf
        end
      end

      # Analytics
      get 'analytics', to: 'analytics#index'
      get 'analytics/calls', to: 'analytics#calls'
      get 'analytics/customers', to: 'analytics#customers'
      
      # AI Chat endpoint
      post 'ai/chat', to: 'ai#chat'
      
      # FreeSWITCH integration
      namespace :freeswitch do
        post 'directory', to: 'freeswitch#directory'
        post 'dialplan', to: 'freeswitch#dialplan'
        post 'configuration', to: 'freeswitch#configuration'
        
        resources :customers, only: [] do
          member do
            get 'sip_credentials', to: 'freeswitch#sip_credentials'
            patch 'sip_credentials', to: 'freeswitch#update_sip_credentials'
            post 'regenerate_sip_password', to: 'freeswitch#regenerate_sip_password'
          end
        end
      end
    end

    # Event handling for external services
    post 'calls/events', to: 'calls#events'

    # Health checks for services
    get 'health/ai_engine', to: 'health#ai_engine'
    get 'health/freeswitch', to: 'health#freeswitch'
    get 'health/all', to: 'health#all_services'
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
