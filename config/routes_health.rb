# ヘルスチェック用ルート
Rails.application.routes.draw do
  get '/health', to: proc { [200, {}, ['OK']] }
  get '/health/detailed', to: 'application#health_check'
end
