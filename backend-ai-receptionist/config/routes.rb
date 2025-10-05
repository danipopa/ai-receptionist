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
