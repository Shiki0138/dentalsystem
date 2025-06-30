# Turbo configuration for performance optimization

# Configure Turbo for better performance
Turbo.configure do |config|
  # Enable turbo-rails optimizations
  config.drive.progressbar.delay = 300
  config.drive.progressbar.enabled = true
end

# Auto-cache frequently accessed pages
Rails.application.configure do
  # Cache turbo frames for better performance
  config.after_initialize do
    ActionView::Base.prepend(Module.new do
      def turbo_frame_tag(id, src: nil, target: nil, **attributes, &block)
        # Add cache headers for turbo frames
        if src.present?
          attributes[:data] ||= {}
          attributes[:data][:turbo_cache] = "true"
        end
        super(id, src: src, target: target, **attributes, &block)
      end
    end)
  end
end

# Configure cache control for turbo streams
if Rails.env.production?
  Rails.application.config.after_initialize do
    # Set cache headers for turbo responses
    ActionController::Base.prepend(Module.new do
      def respond_to(&block)
        super do |format|
          format.turbo_stream do |turbo_format|
            # Add cache control for turbo streams
            response.headers['Cache-Control'] = 'private, max-age=300'
            turbo_format
          end
          block.call(format) if block
        end
      end
    end)
  end
end