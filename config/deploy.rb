# config valid for current version and patch releases of Capistrano
lock "~> 3.17.0"

set :application, "dental_system"
set :repo_url, "git@github.com:username/dental-system.git"

# Default branch is :master
set :branch, 'main'

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, "/var/www/dental_system"

# Default value for :format is :airbrussh.
set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
set :pty, true

# Default value for :linked_files is []
append :linked_files, "config/database.yml", "config/secrets.yml", ".env.production"

# Default value for linked_dirs is []
append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "vendor/bundle", ".bundle", "public/system", "public/uploads"

# Default value for default_env is {}
set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_repository_cache is true
set :local_repository_cache, false

# Default value for keep_releases is 5
set :keep_releases, 5

# Docker Compose deployment tasks
namespace :docker do
  desc 'Pull latest Docker images'
  task :pull do
    on roles(:app) do
      within release_path do
        execute :docker, 'compose', 'pull'
      end
    end
  end

  desc 'Build Docker images'
  task :build do
    on roles(:app) do
      within release_path do
        execute :docker, 'compose', 'build'
      end
    end
  end

  desc 'Stop Docker containers'
  task :stop do
    on roles(:app) do
      within release_path do
        execute :docker, 'compose', 'down'
      end
    end
  end

  desc 'Start Docker containers'
  task :up do
    on roles(:app) do
      within release_path do
        execute :docker, 'compose', 'up', '-d'
      end
    end
  end

  desc 'Restart Docker containers'
  task :restart do
    on roles(:app) do
      within release_path do
        execute :docker, 'compose', 'restart'
      end
    end
  end

  desc 'Run database migrations'
  task :migrate do
    on roles(:app) do
      within release_path do
        execute :docker, 'compose', 'exec', '-T', 'web', 'bundle', 'exec', 'rails', 'db:migrate'
      end
    end
  end
end

# Custom deployment tasks
namespace :deploy do
  desc 'Restart application'
  task :restart do
    invoke 'docker:restart'
  end

  after :publishing, :restart

  desc 'Check Docker and Docker Compose installation'
  task :check_docker do
    on roles(:app) do
      execute :docker, '--version'
      execute :docker, 'compose', '--version'
    end
  end

  before :starting, :check_docker

  desc 'Setup production database'
  task :setup_db do
    invoke 'docker:migrate'
  end

  desc 'Deploy with database setup'
  task :initial do
    invoke 'deploy'
    invoke 'deploy:setup_db'
  end
end