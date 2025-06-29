module DeviceDetection
  extend ActiveSupport::Concern

  included do
    before_action :detect_device_type
    helper_method :current_device_type, :mobile_request?, :tablet_request?, :desktop_request?
  end

  private

  def detect_device_type
    @device_type = determine_device_type
    @is_mobile = @device_type == :mobile
    @is_tablet = @device_type == :tablet
    @is_desktop = @device_type == :desktop
  end

  def determine_device_type
    user_agent = request.user_agent.to_s.downcase
    
    # Check for mobile devices
    mobile_patterns = [
      /mobile/, /android.*mobile/, /iphone/, /ipod/, /blackberry/,
      /opera mini/, /iemobile/, /wpdesktop/, /fennec/, /kindle/,
      /silk/, /mobile.*firefox/, /mobile.*safari/
    ]
    
    # Check for tablet devices
    tablet_patterns = [
      /ipad/, /android(?!.*mobile)/, /tablet/, /playbook/, /silk/,
      /kindle/, /nexus (?:7|9|10)/, /xoom/, /sch-i800/, /galaxy tab/,
      /gt-p\d{4}/, /sm-t/
    ]
    
    return :mobile if mobile_patterns.any? { |pattern| user_agent.match?(pattern) }
    return :tablet if tablet_patterns.any? { |pattern| user_agent.match?(pattern) }
    
    :desktop
  end

  def current_device_type
    @device_type
  end

  def mobile_request?
    @is_mobile
  end

  def tablet_request?
    @is_tablet
  end

  def desktop_request?
    @is_desktop
  end

  # Render device-specific views
  def render_device_view(action_name = action_name, options = {})
    device_suffix = current_device_type == :desktop ? '' : ".#{current_device_type}"
    template_name = "#{action_name}#{device_suffix}"
    
    if template_exists?(template_name)
      render template_name, options
    else
      render action_name, options
    end
  end

  # Set device-specific response format
  def respond_to_device(&block)
    respond_to do |format|
      case current_device_type
      when :mobile
        format.html { render layout: 'mobile' }
        format.json { render json: mobile_json_response }
      when :tablet
        format.html { render layout: 'tablet' }
        format.json { render json: tablet_json_response }
      else
        format.html { render layout: 'application' }
        format.json { render json: desktop_json_response }
      end
      
      yield(format) if block_given?
    end
  end

  # Device-specific pagination
  def device_pagination_params
    case current_device_type
    when :mobile
      { per_page: 5, page: params[:page] || 1 }
    when :tablet
      { per_page: 10, page: params[:page] || 1 }
    else
      { per_page: 20, page: params[:page] || 1 }
    end
  end

  # Device-specific search parameters
  def device_search_params
    base_params = params.permit(:q, :search, :filter)
    
    case current_device_type
    when :mobile
      base_params.merge(limit: 5, autocomplete: true)
    when :tablet
      base_params.merge(limit: 8, autocomplete: true)
    else
      base_params.merge(limit: 10, autocomplete: false)
    end
  end

  # Performance tracking per device
  def track_device_performance
    return unless Rails.env.production?
    
    PerformanceMonitorService.record_request(
      controller_name,
      action_name,
      request_duration_ms,
      response.status,
      device_info: {
        type: current_device_type,
        user_agent: request.user_agent,
        screen_size: request.headers['HTTP_X_SCREEN_SIZE'],
        connection_type: request.headers['HTTP_X_CONNECTION_TYPE']
      }
    )
  end

  # Device-specific error handling
  def handle_device_specific_errors(exception)
    case current_device_type
    when :mobile
      handle_mobile_error(exception)
    when :tablet
      handle_tablet_error(exception)
    else
      handle_desktop_error(exception)
    end
  end

  private

  def mobile_json_response
    # Simplified JSON response for mobile
    if instance_variable_defined?(:@result)
      case @result
      when ActiveRecord::Relation, Array
        {
          data: @result.limit(5).map(&:mobile_attributes),
          has_more: @result.count > 5,
          device: :mobile
        }
      else
        { data: @result.mobile_attributes, device: :mobile }
      end
    else
      { device: :mobile }
    end
  end

  def tablet_json_response
    # Standard JSON response for tablet
    if instance_variable_defined?(:@result)
      case @result
      when ActiveRecord::Relation, Array
        {
          data: @result.limit(10).map(&:tablet_attributes),
          has_more: @result.count > 10,
          device: :tablet
        }
      else
        { data: @result.tablet_attributes, device: :tablet }
      end
    else
      { device: :tablet }
    end
  end

  def desktop_json_response
    # Full JSON response for desktop
    if instance_variable_defined?(:@result)
      case @result
      when ActiveRecord::Relation, Array
        {
          data: @result.map(&:desktop_attributes),
          total: @result.count,
          device: :desktop
        }
      else
        { data: @result.desktop_attributes, device: :desktop }
      end
    else
      { device: :desktop }
    end
  end

  def request_duration_ms
    if instance_variable_defined?(:@request_start_time)
      ((Time.current - @request_start_time) * 1000).round(2)
    else
      0
    end
  end

  def handle_mobile_error(exception)
    # Mobile-specific error handling
    respond_to do |format|
      format.html do
        render 'errors/mobile_error', 
               status: :internal_server_error,
               layout: 'mobile',
               locals: { exception: exception }
      end
      format.json do
        render json: {
          error: 'An error occurred',
          message: 'Please try again or contact support',
          device: :mobile
        }, status: :internal_server_error
      end
    end
  end

  def handle_tablet_error(exception)
    # Tablet-specific error handling
    respond_to do |format|
      format.html do
        render 'errors/tablet_error',
               status: :internal_server_error,
               layout: 'tablet',
               locals: { exception: exception }
      end
      format.json do
        render json: {
          error: exception.class.name,
          message: exception.message,
          device: :tablet
        }, status: :internal_server_error
      end
    end
  end

  def handle_desktop_error(exception)
    # Desktop-specific error handling
    respond_to do |format|
      format.html do
        render 'errors/desktop_error',
               status: :internal_server_error,
               locals: { exception: exception }
      end
      format.json do
        render json: {
          error: exception.class.name,
          message: exception.message,
          backtrace: Rails.env.development? ? exception.backtrace : nil,
          device: :desktop
        }, status: :internal_server_error
      end
    end
  end
end