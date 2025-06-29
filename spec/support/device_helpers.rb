module DeviceHelpers
  # Device viewport dimensions
  DEVICE_VIEWPORTS = {
    desktop: { width: 1920, height: 1080 },
    laptop: { width: 1366, height: 768 },
    tablet_landscape: { width: 1024, height: 768 },
    tablet_portrait: { width: 768, height: 1024 },
    mobile_large: { width: 414, height: 896 },
    mobile_medium: { width: 375, height: 667 },
    mobile_small: { width: 320, height: 568 }
  }.freeze

  # Set viewport size for device testing
  def set_device_viewport(device_type)
    viewport = DEVICE_VIEWPORTS[device_type]
    raise ArgumentError, "Unknown device type: #{device_type}" unless viewport
    
    page.driver.browser.manage.window.resize_to(viewport[:width], viewport[:height])
    
    # Allow time for responsive layout to adjust
    sleep 0.5
  end

  # Check if current viewport matches device category
  def desktop_viewport?
    current_width = page.evaluate_script("window.innerWidth")
    current_width >= 992
  end

  def tablet_viewport?
    current_width = page.evaluate_script("window.innerWidth")
    current_width >= 768 && current_width < 992
  end

  def mobile_viewport?
    current_width = page.evaluate_script("window.innerWidth")
    current_width < 768
  end

  # Simulate touch events for mobile testing
  def touch_element(selector)
    element = find(selector)
    page.driver.browser.action.click(element.native).perform
  end

  def swipe_left(selector)
    element = find(selector)
    page.driver.browser.action
        .move_to(element.native)
        .click_and_hold
        .move_by(-100, 0)
        .release
        .perform
  end

  def swipe_right(selector)
    element = find(selector)
    page.driver.browser.action
        .move_to(element.native)
        .click_and_hold
        .move_by(100, 0)
        .release
        .perform
  end

  # Check responsive design elements
  def has_responsive_navigation?
    if mobile_viewport?
      has_css?('.navbar-mobile') && has_css?('.hamburger-menu')
    elsif tablet_viewport?
      has_css?('.navbar-tablet')
    else
      has_css?('.navbar-desktop')
    end
  end

  def has_device_appropriate_layout?(page_type)
    case page_type
    when :patient_list
      if mobile_viewport?
        has_css?('.patient-mobile-list') && !has_css?('table')
      elsif tablet_viewport?
        has_css?('.patient-cards') && !has_css?('table')
      else
        has_css?('table')
      end
    when :appointment_calendar
      if mobile_viewport?
        has_css?('.appointment-mobile-list')
      elsif tablet_viewport?
        has_css?('.calendar-day-view')
      else
        has_css?('.calendar-week-view')
      end
    when :clocking_interface
      if mobile_viewport?
        has_css?('.clocking-mobile-view')
      elsif tablet_viewport?
        has_css?('.clocking-tablet-view')
      else
        has_css?('.clocking-desktop-view')
      end
    end
  end

  # Simulate GPS location for mobile testing
  def mock_gps_location(latitude: 35.6812, longitude: 139.7671, accuracy: 10)
    page.execute_script("
      navigator.geolocation.getCurrentPosition = function(success, error) {
        success({
          coords: {
            latitude: #{latitude},
            longitude: #{longitude},
            accuracy: #{accuracy}
          },
          timestamp: Date.now()
        });
      };
    ")
  end

  # Test touch-friendly element sizes
  def has_touch_friendly_elements?
    # Buttons should be at least 44px for touch targets
    buttons = all('button, .btn, .touch-target')
    
    buttons.all? do |button|
      height = button.evaluate_script("this.offsetHeight")
      width = button.evaluate_script("this.offsetWidth")
      height >= 44 && width >= 44
    end
  end

  # Check for horizontal scrolling (should not occur on mobile)
  def has_horizontal_scrolling?
    body_width = page.evaluate_script("document.body.scrollWidth")
    viewport_width = page.evaluate_script("window.innerWidth")
    body_width > viewport_width
  end

  # Performance measurement helpers
  def measure_page_load_time(&block)
    start_time = Time.current
    yield
    (Time.current - start_time) * 1000 # Convert to milliseconds
  end

  def measure_interaction_response_time(selector, &block)
    element = find(selector)
    start_time = Time.current
    yield element
    (Time.current - start_time) * 1000
  end

  # Device-specific form helpers
  def fill_mobile_form(form_selector, fields)
    if mobile_viewport? && has_css?("#{form_selector}.mobile-stepper-form")
      fill_stepper_form(form_selector, fields)
    else
      fill_standard_form(form_selector, fields)
    end
  end

  private

  def fill_stepper_form(form_selector, fields)
    within(form_selector) do
      fields.each_with_index do |(field, value), index|
        # Fill current step
        case field
        when /select/
          select value, from: field.gsub('select_', '')
        when /input/
          fill_in field.gsub('input_', ''), with: value
        end
        
        # Move to next step (except for last field)
        if index < fields.length - 1
          click_button '次へ'
          expect(page).to have_css(".step-#{index + 2}.active")
        end
      end
    end
  end

  def fill_standard_form(form_selector, fields)
    within(form_selector) do
      fields.each do |field, value|
        case field
        when /select/
          select value, from: field.gsub('select_', '')
        when /input/
          fill_in field.gsub('input_', ''), with: value
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.include DeviceHelpers, type: :feature
end