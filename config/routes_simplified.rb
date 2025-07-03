# frozen_string_literal: true

Rails.application.routes.draw do
  # Devise認証
  devise_for :users
  
  # ルート
  root 'dashboard#index'
  
  # 患者管理
  resources :patients do
    collection do
      get :search
    end
  end
  
  # 予約管理
  resources :appointments do
    member do
      patch :confirm
      patch :complete
      patch :cancel
    end
    collection do
      get :today
      get :calendar
    end
  end
  
  # ダッシュボード
  get 'dashboard', to: 'dashboard#index'
  
  # 管理者機能（シンプル版）
  namespace :admin do
    resources :users, only: [:index, :new, :create, :edit, :update]
    resource :clinic_setting, only: [:show, :edit, :update]
  end
  
  # 基本レポート
  namespace :reports do
    get :monthly
    get :appointments
    get :patients
  end
  
  # ヘルスチェック
  get 'health', to: proc { [200, {}, ['OK']] }
end