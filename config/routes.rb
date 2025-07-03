Rails.application.routes.draw do
  # ヘルスチェック
  get "/health", to: proc { [200, {"Content-Type" => "text/plain"}, ["OK"]] }
  get "/_ah/health", to: proc { [200, {"Content-Type" => "text/plain"}, ["healthy"]] }
  
  # ベータアクセス
  get '/beta', to: 'beta_login#new', as: :beta_login
  post '/beta/login', to: 'beta_login#create'
  delete '/beta/logout', to: 'beta_login#logout', as: :beta_logout
  
  # メインアプリケーション
  root 'dashboard#index'
  
  # 患者管理
  resources :patients do
    resources :appointments
    resources :treatments
    collection do
      get :search
    end
  end
  
  # 予約管理
  resources :appointments do
    member do
      patch :confirm
      patch :cancel
    end
    collection do
      get :calendar
      get :search_patients
    end
  end
  
  # フィードバック
  post '/beta/feedback', to: 'beta_feedback#create', as: :beta_feedback
  
  # デモデータリセット
  post '/beta/reset', to: 'beta#reset_demo_data', as: :reset_demo_data
  
  # デモモード専用ルート（歯科業界革命体験）
  scope '/demo' do
    get '/', to: 'demo#start', as: :demo_start
    get '/dashboard', to: 'demo#dashboard', as: :demo_dashboard
    post '/seed_data', to: 'demo#seed_data', as: :demo_seed_data
    post '/reset_data', to: 'demo#reset_data', as: :demo_reset_data
    get '/status', to: 'demo#status', as: :demo_status
    get '/ai_demo', to: 'demo#ai_demo', as: :demo_ai
    get '/notification_demo', to: 'demo#notification_demo', as: :demo_notification
    post '/end_session', to: 'demo#end_session', as: :demo_end_session
    
    # 既存のデモルート（下位互換）
    get :realtime_data, to: 'demo#realtime_data'
    get :ai_predictions, to: 'demo#ai_predictions'
    get :system_performance, to: 'demo#system_performance'
    post :update_settings, to: 'demo#update_settings'
    get :toggle_mode, to: 'demo#toggle_mode'
    get :statistics, to: 'demo#statistics'
    get :performance_test
    get :load_test
    get :feature_showcase
  end
  
  # ダッシュボードルート（デモモード対応）
  get '/dashboard', to: 'dashboard#index'
  get '/dashboard/realtime', to: 'dashboard#realtime_enhanced'
  get '/dashboard/demo', to: 'demo#dashboard'
  
  # API routes
  namespace :api do
    # AI統合エンドポイント
    post '/ai/predict', to: 'ai#predict'
    get '/ai/patient_analytics', to: 'ai#patient_analytics'
    post '/ai/realtime_optimization', to: 'ai#realtime_optimization'
    get '/ai/integrated_dashboard', to: 'ai#integrated_dashboard'
    
    # AI予約最適化エンドポイント
    post 'ai/suggest_appointment_time', to: 'ai#suggest_appointment_time'
    post 'ai/predict_conflicts', to: 'ai#predict_conflicts'
    post 'ai/optimize_recurring', to: 'ai#optimize_recurring'
  end
end
