Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get "health", to: "health#show"
    end
  end
  devise_for :users
  root "dashboard#index"

  # ActionMailbox routes
  mount ActionMailbox::Engine => "/rails/action_mailbox"

  # Dashboard
  get "dashboard", to: "dashboard#index"
  
  # Manual booking interface
  namespace :book do
    get :manual, to: "manual#index"
    post :manual, to: "manual#create"
    get :search_patients, to: "manual#search_patients"
    get :available_slots, to: "manual#available_slots"
  end

  # Appointments
  resources :appointments do
    member do
      patch :visit
      patch :cancel
      patch :confirm
    end
    
    collection do
      get :today
      get :upcoming
      get :search
    end
  end

  # Patients
  resources :patients do
    member do
      get :history
      post :merge_with
    end
    
    collection do
      get :search
      get :duplicates
    end
  end

  # API routes
  namespace :api do
    namespace :v1 do
      resources :appointments, only: [:index, :show, :create, :update]
      resources :patients, only: [:index, :show, :create, :update] do
        collection do
          get :search
        end
      end
      resources :reminders, only: [:index, :create]
    end
  end
  
  # Background jobs monitoring (Sidekiq Web UI)
  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq"
  
  # Employee management
  resources :employees do
    resources :clockings, except: [:show]
    member do
      get :timesheet
    end
  end
  
  # Payroll management
  resources :payrolls, only: [:index, :show, :create]
  
  # Admin routes
  namespace :admin do
    resources :users
    resources :settings, only: [:index, :update]
    resources :reports, only: [:index, :show]
    
    resources :payrolls do
      member do
        patch :approve
        patch :mark_as_paid
      end
      collection do
        post :calculate_all
        get :export
      end
    end
    
    resources :employees do
      resources :clockings
    end
  end
  
  # Webhooks
  namespace :webhooks do
    post 'line', to: 'line#callback'
    post 'gmail', to: 'gmail#callback'
  end
end