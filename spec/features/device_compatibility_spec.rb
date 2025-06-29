require 'rails_helper'

RSpec.describe 'Device Compatibility', type: :feature, js: true do
  describe 'PC Desktop Browser' do
    before do
      page.driver.browser.manage.window.resize_to(1920, 1080)
    end

    context 'Patient Management' do
      it 'displays patient list with full details' do
        patients = create_list(:patient, 10)
        
        visit patients_path
        
        expect(page).to have_css('[data-device="desktop"]')
        expect(page).to have_content('患者一覧')
        
        # Desktop view should show full patient details
        patients.each do |patient|
          expect(page).to have_content(patient.name)
          expect(page).to have_content(patient.name_kana)
          expect(page).to have_content(patient.phone) if patient.phone.present?
          expect(page).to have_content(patient.email) if patient.email.present?
        end
        
        # Check table headers are visible
        expect(page).to have_css('table thead th', count: 6)
        
        # Check pagination controls
        expect(page).to have_css('.pagination')
      end
      
      it 'allows patient search with desktop UI' do
        patient = create(:patient, name: '田中太郎', name_kana: 'タナカタロウ')
        
        visit patients_path
        
        fill_in 'search', with: '田中'
        click_button '検索'
        
        expect(page).to have_content('田中太郎')
        expect(page).to have_content('タナカタロウ')
      end
    end

    context 'Appointment Management' do
      it 'displays appointment calendar with full controls' do
        employee = create(:employee)
        patient = create(:patient)
        appointment = create(:appointment, patient: patient, employee: employee)
        
        visit appointments_path
        
        # Desktop calendar should show week view by default
        expect(page).to have_css('.calendar-week-view')
        expect(page).to have_css('.calendar-controls')
        
        # Should display appointment details
        expect(page).to have_content(patient.name)
        expect(page).to have_content(appointment.appointment_time.strftime('%H:%M'))
        
        # Should have action buttons
        expect(page).to have_css('button', text: '編集')
        expect(page).to have_css('button', text: '削除')
      end
      
      it 'allows appointment creation with desktop form' do
        patient = create(:patient)
        employee = create(:employee)
        
        visit new_appointment_path
        
        select patient.name, from: 'appointment_patient_id'
        select employee.name, from: 'appointment_employee_id'
        fill_in 'appointment_appointment_date', with: Date.tomorrow
        fill_in 'appointment_appointment_time', with: '10:00'
        fill_in 'appointment_notes', with: 'デスクトップからの予約'
        
        click_button '予約作成'
        
        expect(page).to have_content('予約が作成されました')
        expect(page).to have_content(patient.name)
      end
    end

    context 'Employee Management' do
      it 'displays employee clocking interface' do
        employee = create(:employee)
        
        visit employee_clockings_path(employee)
        
        # Desktop should show detailed clocking history
        expect(page).to have_css('.clocking-history table')
        expect(page).to have_css('button', text: '出勤')
        expect(page).to have_css('button', text: '退勤')
        expect(page).to have_css('button', text: '休憩開始')
        expect(page).to have_css('button', text: '休憩終了')
        
        # Should show monthly summary
        expect(page).to have_css('.monthly-summary')
      end
    end
  end

  describe 'Tablet Browser' do
    before do
      page.driver.browser.manage.window.resize_to(768, 1024)
    end

    context 'Patient Management' do
      it 'displays patient list with tablet-optimized layout' do
        patients = create_list(:patient, 10)
        
        visit patients_path
        
        expect(page).to have_css('[data-device="tablet"]')
        
        # Tablet view should show card layout instead of table
        expect(page).to have_css('.patient-cards')
        expect(page).not_to have_css('table')
        
        patients.each do |patient|
          expect(page).to have_content(patient.name)
          expect(page).to have_content(patient.name_kana)
        end
        
        # Touch-friendly buttons
        expect(page).to have_css('button.btn-large')
      end
      
      it 'provides touch-friendly search interface' do
        patient = create(:patient, name: '田中太郎')
        
        visit patients_path
        
        # Tablet search should be larger and touch-friendly
        search_input = find('#search')
        expect(search_input[:class]).to include('form-control-lg')
        
        fill_in 'search', with: '田中'
        click_button '検索'
        
        expect(page).to have_content('田中太郎')
      end
    end

    context 'Appointment Management' do
      it 'displays appointment calendar with tablet interface' do
        employee = create(:employee)
        patient = create(:patient)
        appointment = create(:appointment, patient: patient, employee: employee)
        
        visit appointments_path
        
        # Tablet should show daily view by default
        expect(page).to have_css('.calendar-day-view')
        expect(page).to have_css('.calendar-touch-controls')
        
        # Swipe navigation should be available
        expect(page).to have_css('[data-swipe="enabled"]')
        
        # Touch-friendly appointment blocks
        expect(page).to have_css('.appointment-block.touch-friendly')
      end
      
      it 'allows appointment creation with tablet form' do
        patient = create(:patient)
        employee = create(:employee)
        
        visit new_appointment_path
        
        # Form should be touch-optimized
        expect(page).to have_css('form.tablet-form')
        expect(page).to have_css('select.form-control-lg')
        expect(page).to have_css('input.form-control-lg')
        
        select patient.name, from: 'appointment_patient_id'
        select employee.name, from: 'appointment_employee_id'
        fill_in 'appointment_appointment_date', with: Date.tomorrow
        fill_in 'appointment_appointment_time', with: '10:00'
        
        click_button '予約作成'
        
        expect(page).to have_content('予約が作成されました')
      end
    end

    context 'Employee Management' do
      it 'displays employee clocking interface for tablet' do
        employee = create(:employee)
        
        visit employee_clockings_path(employee)
        
        # Tablet should show simplified clocking interface
        expect(page).to have_css('.clocking-tablet-view')
        expect(page).to have_css('button.clocking-btn-large')
        
        # Touch-friendly time display
        expect(page).to have_css('.current-time-large')
        
        # Simplified history view
        expect(page).to have_css('.clocking-history-cards')
        expect(page).not_to have_css('.clocking-history table')
      end
    end
  end

  describe 'Smartphone Browser' do
    before do
      page.driver.browser.manage.window.resize_to(375, 667)
    end

    context 'Patient Management' do
      it 'displays patient list with mobile-optimized layout' do
        patients = create_list(:patient, 10)
        
        visit patients_path
        
        expect(page).to have_css('[data-device="mobile"]')
        
        # Mobile view should show compact list
        expect(page).to have_css('.patient-mobile-list')
        expect(page).not_to have_css('table')
        expect(page).not_to have_css('.patient-cards')
        
        # Show only essential information
        patients.first(5).each do |patient|
          expect(page).to have_content(patient.name)
        end
        
        # Mobile pagination
        expect(page).to have_css('.pagination-mobile')
        
        # Touch-friendly buttons
        expect(page).to have_css('button.btn-mobile')
      end
      
      it 'provides mobile search with autocomplete' do
        patient = create(:patient, name: '田中太郎')
        
        visit patients_path
        
        # Mobile search should have autocomplete
        expect(page).to have_css('input[data-autocomplete="true"]')
        
        fill_in 'search', with: '田中'
        
        # Should show suggestions
        expect(page).to have_css('.search-suggestions')
        
        click_button '検索'
        
        expect(page).to have_content('田中太郎')
      end
    end

    context 'Appointment Management' do
      it 'displays appointment calendar with mobile interface' do
        employee = create(:employee)
        patient = create(:patient)
        appointment = create(:appointment, patient: patient, employee: employee)
        
        visit appointments_path
        
        # Mobile should show list view
        expect(page).to have_css('.appointment-mobile-list')
        expect(page).not_to have_css('.calendar-week-view')
        expect(page).not_to have_css('.calendar-day-view')
        
        # Swipe navigation
        expect(page).to have_css('[data-swipe="enabled"]')
        
        # Bottom navigation
        expect(page).to have_css('.bottom-navigation')
        
        # Appointment should be shown as card
        expect(page).to have_css('.appointment-card')
        expect(page).to have_content(patient.name)
      end
      
      it 'allows appointment creation with mobile form' do
        patient = create(:patient)
        employee = create(:employee)
        
        visit new_appointment_path
        
        # Mobile form should be step-by-step
        expect(page).to have_css('form.mobile-stepper-form')
        expect(page).to have_css('.step-indicator')
        
        # Step 1: Patient selection
        expect(page).to have_css('.step-1.active')
        select patient.name, from: 'appointment_patient_id'
        click_button '次へ'
        
        # Step 2: Date/Time selection
        expect(page).to have_css('.step-2.active')
        fill_in 'appointment_appointment_date', with: Date.tomorrow
        fill_in 'appointment_appointment_time', with: '10:00'
        click_button '次へ'
        
        # Step 3: Confirmation
        expect(page).to have_css('.step-3.active')
        click_button '予約作成'
        
        expect(page).to have_content('予約が作成されました')
      end
    end

    context 'Employee Management' do
      it 'displays employee clocking interface for mobile' do
        employee = create(:employee)
        
        visit employee_clockings_path(employee)
        
        # Mobile should show single-tap clocking
        expect(page).to have_css('.clocking-mobile-view')
        expect(page).to have_css('button.clocking-btn-mobile')
        
        # Large time display
        expect(page).to have_css('.current-time-mobile')
        
        # Minimal history view
        expect(page).to have_css('.clocking-history-minimal')
        
        # GPS status indicator
        expect(page).to have_css('.gps-status')
      end
      
      it 'supports GPS-based location validation' do
        employee = create(:employee)
        
        visit employee_clockings_path(employee)
        
        # Mock GPS coordinates
        page.execute_script("
          navigator.geolocation.getCurrentPosition = function(success) {
            success({
              coords: {
                latitude: 35.6812,
                longitude: 139.7671,
                accuracy: 10
              }
            });
          };
        ")
        
        click_button '出勤'
        
        # Should show location confirmation
        expect(page).to have_content('位置情報を確認中')
        
        # Should proceed with clocking
        expect(page).to have_content('出勤記録が保存されました')
      end
    end
  end

  describe 'Cross-Device Responsive Behavior' do
    it 'adapts navigation menu based on screen size' do
      visit root_path
      
      # Desktop navigation
      page.driver.browser.manage.window.resize_to(1920, 1080)
      expect(page).to have_css('.navbar-desktop')
      expect(page).not_to have_css('.navbar-mobile')
      
      # Tablet navigation
      page.driver.browser.manage.window.resize_to(768, 1024)
      expect(page).to have_css('.navbar-tablet')
      
      # Mobile navigation
      page.driver.browser.manage.window.resize_to(375, 667)
      expect(page).to have_css('.navbar-mobile')
      expect(page).to have_css('.hamburger-menu')
      expect(page).not_to have_css('.navbar-desktop')
    end
    
    it 'maintains functionality across all device sizes' do
      patient = create(:patient)
      
      # Test on all device sizes
      [
        [1920, 1080], # Desktop
        [768, 1024],  # Tablet
        [375, 667]    # Mobile
      ].each do |width, height|
        page.driver.browser.manage.window.resize_to(width, height)
        
        visit patients_path
        
        # Search should work on all devices
        fill_in 'search', with: patient.name
        click_button '検索'
        
        expect(page).to have_content(patient.name)
        
        # Clear search
        fill_in 'search', with: ''
        click_button '検索'
      end
    end
    
    it 'handles touch and click events appropriately' do
      visit root_path
      
      # Desktop should use click events
      page.driver.browser.manage.window.resize_to(1920, 1080)
      expect(page).to have_css('[data-event="click"]')
      
      # Mobile should use touch events
      page.driver.browser.manage.window.resize_to(375, 667)
      expect(page).to have_css('[data-event="touch"]')
    end
  end

  describe 'Performance Across Devices' do
    it 'loads pages within acceptable time limits' do
      # Test page load performance on different devices
      devices = [
        { width: 1920, height: 1080, name: 'Desktop' },
        { width: 768, height: 1024, name: 'Tablet' },
        { width: 375, height: 667, name: 'Mobile' }
      ]
      
      devices.each do |device|
        page.driver.browser.manage.window.resize_to(device[:width], device[:height])
        
        start_time = Time.current
        visit patients_path
        load_time = (Time.current - start_time) * 1000
        
        expect(load_time).to be < 3000 # 3 seconds as per development rules
        
        # Check that all critical elements are loaded
        expect(page).to have_css('[data-device]')
        expect(page).to have_content('患者一覧')
      end
    end
    
    it 'maintains smooth interactions on touch devices' do
      page.driver.browser.manage.window.resize_to(375, 667)
      
      create_list(:patient, 20)
      visit patients_path
      
      # Scroll should be smooth
      page.execute_script("window.scrollTo(0, 500);")
      sleep 0.5
      
      # Touch interactions should be responsive
      expect(page).to have_css('.touch-friendly')
      
      # No horizontal scrolling on mobile
      page_width = page.execute_script("return document.body.scrollWidth;")
      viewport_width = page.execute_script("return window.innerWidth;")
      
      expect(page_width).to be <= viewport_width
    end
  end
end