module DeviceHelper
  # Detect device type from user agent
  def device_type
    user_agent = request.user_agent.to_s.downcase
    
    case user_agent
    when /mobile|android|iphone|ipod|blackberry|opera mini|iemobile|wpdesktop/
      :mobile
    when /tablet|ipad|playbook|silk/
      :tablet
    else
      :desktop
    end
  end

  # Check if current request is from mobile device
  def mobile_device?
    device_type == :mobile
  end

  # Check if current request is from tablet device
  def tablet_device?
    device_type == :tablet
  end

  # Check if current request is from desktop device
  def desktop_device?
    device_type == :desktop
  end

  # Get responsive CSS classes based on device
  def device_classes
    base_classes = ['responsive-layout']
    
    case device_type
    when :mobile
      base_classes << 'mobile-layout'
    when :tablet
      base_classes << 'tablet-layout'
    else
      base_classes << 'desktop-layout'
    end
    
    base_classes.join(' ')
  end

  # Generate device-specific data attributes
  def device_data_attributes
    {
      device: device_type.to_s,
      'touch-enabled': (mobile_device? || tablet_device?).to_s,
      'responsive': 'true'
    }
  end

  # Get appropriate viewport meta tag
  def viewport_meta_tag
    if mobile_device?
      tag.meta(name: 'viewport', content: 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no')
    elsif tablet_device?
      tag.meta(name: 'viewport', content: 'width=device-width, initial-scale=1.0, maximum-scale=2.0')
    else
      tag.meta(name: 'viewport', content: 'width=device-width, initial-scale=1.0')
    end
  end

  # Get device-appropriate page title
  def device_page_title(base_title)
    case device_type
    when :mobile
      # Shorter titles for mobile
      base_title.length > 20 ? "#{base_title[0..17]}..." : base_title
    else
      base_title
    end
  end

  # Generate device-specific navigation structure
  def device_navigation_structure
    if mobile_device?
      {
        type: :hamburger,
        placement: :top,
        collapsible: true
      }
    elsif tablet_device?
      {
        type: :tabs,
        placement: :top,
        collapsible: false
      }
    else
      {
        type: :horizontal,
        placement: :top,
        collapsible: false
      }
    end
  end

  # Get appropriate form layout
  def device_form_layout
    case device_type
    when :mobile
      :stepper # Step-by-step form for mobile
    when :tablet
      :card # Card-based layout for tablet
    else
      :standard # Standard form layout for desktop
    end
  end

  # Get appropriate table layout
  def device_table_layout
    case device_type
    when :mobile
      :cards # Card layout instead of table
    when :tablet
      :grid # Grid layout for tablet
    else
      :table # Standard table for desktop
    end
  end

  # Get touch-friendly button size
  def touch_button_classes
    base_classes = ['btn']
    
    if mobile_device?
      base_classes << 'btn-mobile' << 'btn-lg'
    elsif tablet_device?
      base_classes << 'btn-tablet' << 'btn-lg'
    else
      base_classes << 'btn-desktop'
    end
    
    base_classes.join(' ')
  end

  # Generate CSS classes for responsive images
  def responsive_image_classes
    classes = ['img-responsive']
    
    case device_type
    when :mobile
      classes << 'img-mobile'
    when :tablet
      classes << 'img-tablet'
    else
      classes << 'img-desktop'
    end
    
    classes.join(' ')
  end

  # Get appropriate pagination style
  def device_pagination_options
    case device_type
    when :mobile
      { per_page: 5, style: :minimal }
    when :tablet
      { per_page: 10, style: :compact }
    else
      { per_page: 20, style: :full }
    end
  end

  # Generate appropriate calendar view options
  def device_calendar_options
    case device_type
    when :mobile
      { view: :list, navigation: :swipe }
    when :tablet
      { view: :day, navigation: :touch }
    else
      { view: :week, navigation: :click }
    end
  end

  # Check if GPS functionality should be enabled
  def gps_enabled?
    mobile_device? || tablet_device?
  end

  # Get appropriate search options
  def device_search_options
    case device_type
    when :mobile
      { autocomplete: true, suggestions: 5, instant: true }
    when :tablet
      { autocomplete: true, suggestions: 8, instant: false }
    else
      { autocomplete: false, suggestions: 10, instant: false }
    end
  end

  # Generate device-specific JavaScript includes
  def device_javascript_includes
    js_files = ['application']
    
    case device_type
    when :mobile
      js_files << 'mobile' << 'touch' << 'geolocation'
    when :tablet
      js_files << 'tablet' << 'touch'
    else
      js_files << 'desktop'
    end
    
    js_files
  end

  # Generate device-specific CSS includes
  def device_stylesheet_includes
    css_files = ['application']
    
    case device_type
    when :mobile
      css_files << 'mobile' << 'touch'
    when :tablet
      css_files << 'tablet' << 'touch'
    else
      css_files << 'desktop'
    end
    
    css_files
  end

  # Get appropriate modal options
  def device_modal_options
    case device_type
    when :mobile
      { 
        backdrop: false, 
        keyboard: true, 
        show: true,
        size: 'fullscreen'
      }
    when :tablet
      { 
        backdrop: true, 
        keyboard: true, 
        show: true,
        size: 'large'
      }
    else
      { 
        backdrop: true, 
        keyboard: true, 
        show: true,
        size: 'default'
      }
    end
  end

  # Get performance optimization settings
  def device_performance_settings
    case device_type
    when :mobile
      {
        lazy_loading: true,
        image_compression: :high,
        js_defer: true,
        css_inline_critical: true
      }
    when :tablet
      {
        lazy_loading: true,
        image_compression: :medium,
        js_defer: false,
        css_inline_critical: false
      }
    else
      {
        lazy_loading: false,
        image_compression: :low,
        js_defer: false,
        css_inline_critical: false
      }
    end
  end
end