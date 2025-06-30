class Api::V1::HealthController < ApplicationController
  skip_before_action :authenticate_user!, only: [:show]
  
  def show
    status = {
      status: 'healthy',
      timestamp: Time.current.iso8601,
      version: Rails.application.config.version || '1.0.0',
      environment: Rails.env,
      database: database_status,
      redis: redis_status,
      services: service_status
    }
    
    render json: status, status: :ok
  rescue => e
    render json: { 
      status: 'unhealthy', 
      error: e.message,
      timestamp: Time.current.iso8601 
    }, status: :service_unavailable
  end
  
  private
  
  def database_status
    ActiveRecord::Base.connection.execute('SELECT 1')
    'connected'
  rescue => e
    "error: #{e.message}"
  end
  
  def redis_status
    Redis.current.ping
    'connected'
  rescue => e
    "error: #{e.message}"
  end
  
  def service_status
    {
      sidekiq: sidekiq_status,
      disk_space: disk_usage,
      memory: memory_usage
    }
  end
  
  def sidekiq_status
    Sidekiq::Stats.new.processed > 0 ? 'active' : 'idle'
  rescue
    'unavailable'
  end
  
  def disk_usage
    `df -h /`.lines.last.split[4] rescue 'unknown'
  end
  
  def memory_usage
    `free -m | grep '^Mem:' | awk '{print $3"/"$2"MB"}'`.strip rescue 'unknown'
  end
end
