# Production deployment configuration
server 'your-server-ip', user: 'deploy', roles: %w{app db web}, primary: true

# Server-specific options for AWS Lightsail
set :stage, :production
set :rails_env, :production

# SSH options for AWS Lightsail
set :ssh_options, {
  keys: %w(~/.ssh/lightsail-key.pem),
  forward_agent: true,
  auth_methods: %w(publickey),
  user: 'ubuntu'
}

# Production-specific settings
set :branch, 'main'
set :deploy_to, '/var/www/dental_system'

# Environment variables
set :default_env, {
  'RAILS_ENV' => 'production',
  'NODE_ENV' => 'production'
}

# Nginx configuration
set :nginx_server_name, 'dental-system.example.com'
set :nginx_use_ssl, true

# SSL certificate paths (Let's Encrypt)
set :ssl_certificate_path, '/etc/letsencrypt/live/dental-system.example.com/fullchain.pem'
set :ssl_certificate_key_path, '/etc/letsencrypt/live/dental-system.example.com/privkey.pem'

# Database backup before deployment
before 'deploy:starting', 'backup:db'

namespace :backup do
  desc 'Backup production database'
  task :db do
    on roles(:db) do
      within release_path do
        timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
        backup_file = "/var/backups/dental_system_#{timestamp}.sql"
        execute :sudo, :mkdir, '-p', '/var/backups'
        execute :docker, 'compose', 'exec', '-T', 'db', 'pg_dump', '-U', 'postgres', 'dental_system_production', '|', :sudo, :tee, backup_file
        info "Database backup created: #{backup_file}"
      end
    end
  end
end