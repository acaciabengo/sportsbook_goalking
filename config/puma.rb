# Calculate threads based on environment
threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
threads threads_count, threads_count

# Add workers to use multiple CPUs
# For CPU-bound work, match your CPU count
# For I/O-bound work (like ActionCable), you can go slightly higher
workers ENV.fetch("WEB_CONCURRENCY", 4)

# Preload the application before forking workers
preload_app!

port ENV.fetch("PORT", 3000)

plugin :tmp_restart

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]

# Set up hooks for database connections
before_fork do
  ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
end

on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
  
  # If using Redis for ActionCable
  if defined?(Redis)
    Redis.current.disconnect!
  end
end

# Recommended: Allow workers to restart gracefully
worker_timeout 30
worker_boot_timeout 30
worker_shutdown_timeout 15

# Optional: Restart workers periodically to prevent memory bloat
# Good for long-running ActionCable connections

worker_killer_enabled = ENV.fetch("PUMA_WORKER_KILLER_ENABLED", "false") == "true"
if worker_killer_enabled
  # Requires gem 'puma_worker_killer'
  before_fork do
    require 'puma_worker_killer'
    PumaWorkerKiller.enable_rolling_restart(3 * 60 * 60) # 3 hours
  end
end