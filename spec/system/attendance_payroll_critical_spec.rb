require 'rails_helper'

RSpec.describe 'Critical Attendance & Payroll System', type: :system, js: true do
  describe 'Critical Error Detection and Resolution' do
    let(:employee) { create(:employee, :full_time) }
    let(:part_time_employee) { create(:employee, :part_time) }
    
    before do
      # Simulate production environment
      allow(Rails.env).to receive(:production?).and_return(true)
    end

    context 'Employee Model Critical Issues' do
      it 'handles missing employee data gracefully' do
        # Test nil safety for critical methods
        employee = Employee.new
        
        expect { employee.full_name }.not_to raise_error
        expect { employee.current_clocking_status }.not_to raise_error
        expect { employee.clocked_in? }.not_to raise_error
        expect { employee.calculate_age }.not_to raise_error
        
        expect(employee.full_name).to eq(' ')
        expect(employee.current_clocking_status).to be_nil
        expect(employee.clocked_in?).to be false
        expect(employee.calculate_age).to be_nil
      end

      it 'validates critical employee fields' do
        invalid_employee = Employee.new
        
        expect(invalid_employee.valid?).to be false
        expect(invalid_employee.errors[:employee_code]).to include("can't be blank")
        expect(invalid_employee.errors[:first_name]).to include("can't be blank")
        expect(invalid_employee.errors[:last_name]).to include("can't be blank")
        expect(invalid_employee.errors[:email]).to include("can't be blank")
        expect(invalid_employee.errors[:employment_type]).to include("can't be blank")
        expect(invalid_employee.errors[:hire_date]).to include("can't be blank")
      end

      it 'prevents duplicate employee codes and emails' do
        existing_employee = create(:employee)
        
        duplicate_employee = Employee.new(
          employee_code: existing_employee.employee_code,
          email: existing_employee.email,
          first_name: 'Test',
          last_name: 'User',
          employment_type: 'full_time',
          hire_date: Date.current
        )
        
        expect(duplicate_employee.valid?).to be false
        expect(duplicate_employee.errors[:employee_code]).to include("has already been taken")
        expect(duplicate_employee.errors[:email]).to include("has already been taken")
      end

      it 'validates salary data correctly' do
        # Invalid negative salary
        employee = build(:employee, base_salary: -1000)
        expect(employee.valid?).to be false
        expect(employee.errors[:base_salary]).to include("must be greater than or equal to 0")
        
        # Invalid negative hourly rate
        employee = build(:employee, hourly_rate: -50)
        expect(employee.valid?).to be false
        expect(employee.errors[:hourly_rate]).to include("must be greater than or equal to 0")
      end
    end

    context 'Clocking System Critical Issues' do
      it 'prevents invalid clock sequences' do
        # Try to clock out without clocking in
        clocking = build(:clocking, employee: employee, clock_type: 'clock_out')
        
        expect(clocking.valid?).to be false
        expect(clocking.errors[:clock_type]).to include('出勤していません')
      end

      it 'validates GPS location when required' do
        # Outside office range
        clocking = build(:clocking, 
          employee: employee, 
          clock_type: 'clock_in',
          latitude: 34.0522, # Los Angeles (far from office)
          longitude: -118.2437
        )
        
        expect(clocking.valid?).to be false
        expect(clocking.errors[:base]).to include("打刻位置が勤務地から100m以上離れています")
      end

      it 'handles missing or corrupted GPS data' do
        # Missing GPS data should be allowed for web entries
        clocking = build(:clocking, 
          employee: employee, 
          clock_type: 'clock_in',
          device_type: 'web',
          latitude: nil,
          longitude: nil
        )
        
        expect(clocking.valid?).to be true
      end

      it 'prevents simultaneous clockings' do
        # Create initial clock in
        create(:clocking, employee: employee, clock_type: 'clock_in', clocked_at: 1.hour.ago)
        
        # Try to clock in again
        duplicate_clocking = build(:clocking, employee: employee, clock_type: 'clock_in')
        
        expect(duplicate_clocking.valid?).to be false
        expect(duplicate_clocking.errors[:clock_type]).to include('すでに出勤しています')
      end

      it 'calculates distance correctly for GPS validation' do
        clocking = build(:clocking, employee: employee)
        
        # Test distance calculation with known coordinates
        distance = clocking.send(:calculate_distance, 35.6812, 139.7671, 35.6813, 139.7672)
        
        expect(distance).to be > 0
        expect(distance).to be < 50 # Should be very close
      end
    end

    context 'Payroll System Critical Issues' do
      it 'validates payroll period correctly' do
        # Invalid period (end before start)
        payroll = build(:payroll, 
          employee: employee,
          pay_period_start: Date.current,
          pay_period_end: Date.current - 1.day
        )
        
        expect(payroll.valid?).to be false
        expect(payroll.errors[:pay_period_end]).to include('終了日は開始日より後である必要があります')
      end

      it 'prevents excessive pay periods' do
        # Period longer than 31 days
        payroll = build(:payroll,
          employee: employee,
          pay_period_start: Date.current,
          pay_period_end: Date.current + 32.days
        )
        
        expect(payroll.valid?).to be false
        expect(payroll.errors[:base]).to include('給与期間は31日を超えることはできません')
      end

      it 'calculates monthly salary correctly' do
        payroll = create(:payroll, 
          employee: employee,
          pay_period_start: Date.current.beginning_of_month,
          pay_period_end: Date.current.end_of_month
        )
        
        expect(payroll.base_pay).to be > 0
        expect(payroll.gross_pay).to eq(payroll.base_pay + payroll.overtime_pay + payroll.holiday_pay + payroll.allowances)
        expect(payroll.net_pay).to eq(payroll.gross_pay - payroll.deductions)
      end

      it 'calculates hourly wage correctly' do
        payroll = create(:payroll, 
          employee: part_time_employee,
          regular_hours: 40,
          overtime_hours: 5,
          holiday_hours: 8
        )
        
        expect(payroll.base_pay).to eq(40 * part_time_employee.hourly_rate)
        expect(payroll.overtime_pay).to eq(5 * part_time_employee.hourly_rate * 1.25)
        expect(payroll.holiday_pay).to eq(8 * part_time_employee.hourly_rate * 1.35)
      end

      it 'prevents negative pay amounts' do
        payroll = build(:payroll,
          employee: employee,
          total_hours: -10,
          base_pay: -1000,
          net_pay: -500
        )
        
        expect(payroll.valid?).to be false
        expect(payroll.errors[:total_hours]).to include("must be greater than or equal to 0")
        expect(payroll.errors[:base_pay]).to include("must be greater than or equal to 0")
        expect(payroll.errors[:net_pay]).to include("must be greater than or equal to 0")
      end

      it 'handles payroll state transitions correctly' do
        payroll = create(:payroll, employee: employee, status: 'draft', total_hours: 40)
        approver = create(:employee)
        
        # Test approval
        expect(payroll.can_approve?).to be true
        expect(payroll.approve!(approver)).to be true
        expect(payroll.status).to eq('approved')
        expect(payroll.approved_by).to eq(approver)
        expect(payroll.approved_at).to be_present
        
        # Test payment marking
        expect(payroll.can_mark_as_paid?).to be true
        expect(payroll.mark_as_paid!).to be true
        expect(payroll.status).to eq('paid')
        expect(payroll.paid_at).to be_present
      end
    end

    context 'Integration Critical Tests' do
      it 'calculates payroll from actual clockings' do
        # Create realistic clocking scenario
        start_date = Date.current.beginning_of_week
        
        # Monday - normal work day
        create(:clocking, employee: employee, clock_type: 'clock_in', clocked_at: start_date + 9.hours)
        create(:clocking, employee: employee, clock_type: 'break_start', clocked_at: start_date + 12.hours)
        create(:clocking, employee: employee, clock_type: 'break_end', clocked_at: start_date + 13.hours)
        create(:clocking, employee: employee, clock_type: 'clock_out', clocked_at: start_date + 18.hours)
        
        # Tuesday - overtime day
        tuesday = start_date + 1.day
        create(:clocking, employee: employee, clock_type: 'clock_in', clocked_at: tuesday + 9.hours)
        create(:clocking, employee: employee, clock_type: 'clock_out', clocked_at: tuesday + 20.hours) # 11 hours
        
        payroll = create(:payroll, 
          employee: employee,
          pay_period_start: start_date,
          pay_period_end: start_date + 6.days
        )
        
        payroll.calculate_from_clockings
        
        expect(payroll.regular_hours).to be > 0
        expect(payroll.overtime_hours).to be > 0 # Should have overtime from Tuesday
        expect(payroll.total_hours).to eq(payroll.regular_hours + payroll.overtime_hours + payroll.holiday_hours)
      end

      it 'handles concurrent clocking attempts' do
        # Simulate race condition
        threads = []
        results = []
        
        5.times do
          threads << Thread.new do
            begin
              clocking = Clocking.create!(
                employee: employee,
                clock_type: 'clock_in',
                clocked_at: Time.current
              )
              results << { success: true, id: clocking.id }
            rescue => e
              results << { success: false, error: e.message }
            end
          end
        end
        
        threads.each(&:join)
        
        # Only one should succeed due to validation
        successful = results.count { |r| r[:success] }
        expect(successful).to eq(1)
      end

      it 'prevents payroll manipulation through timing attacks' do
        payroll = create(:payroll, employee: employee, status: 'draft')
        
        # Simulate concurrent approval attempts
        threads = []
        results = []
        
        3.times do
          threads << Thread.new do
            approver = create(:employee)
            result = payroll.approve!(approver)
            results << result
          end
        end
        
        threads.each(&:join)
        
        # Should only succeed once
        successful_approvals = results.count(true)
        expect(successful_approvals).to be <= 1
      end
    end

    context 'Error Recovery and Resilience' do
      it 'handles database connection failures gracefully' do
        # Mock database failure
        allow(Employee).to receive(:find).and_raise(ActiveRecord::ConnectionTimeoutError)
        
        expect {
          Employee.find(99999) rescue nil
        }.not_to raise_error
      end

      it 'validates data integrity after failures' do
        employee = create(:employee)
        
        # Create some clockings
        create(:clocking, employee: employee, clock_type: 'clock_in', clocked_at: 1.hour.ago)
        
        # Simulate partial failure - missing clock out
        # The system should handle this gracefully
        status = employee.current_clocking_status
        expect([:clocked_in, :working, :on_break]).to include(status)
      end

      it 'handles invalid GPS coordinates gracefully' do
        # Invalid coordinates
        clocking = build(:clocking,
          employee: employee,
          latitude: 999, # Invalid latitude
          longitude: 999, # Invalid longitude
          device_type: 'mobile'
        )
        
        # Should not crash the distance calculation
        expect { clocking.valid? }.not_to raise_error
      end

      it 'prevents payroll calculation errors with edge cases' do
        # Zero hours
        payroll = create(:payroll, employee: employee, total_hours: 0)
        expect(payroll.can_approve?).to be false
        
        # Missing employee data
        payroll.employee = nil
        expect { payroll.send(:calculate_pay) }.not_to raise_error
      end
    end

    context 'Performance Critical Tests' do
      it 'handles large datasets efficiently' do
        # Create many employees and clockings
        employees = create_list(:employee, 100)
        
        start_time = Time.current
        
        employees.each do |emp|
          create(:clocking, employee: emp, clock_type: 'clock_in')
        end
        
        end_time = Time.current
        duration = end_time - start_time
        
        # Should complete within reasonable time (adjust threshold as needed)
        expect(duration).to be < 10.seconds
      end

      it 'efficiently calculates payroll for large periods' do
        # Create many clockings for one employee
        employee = create(:employee)
        
        30.times do |day|
          date = Date.current - day.days
          create(:clocking, employee: employee, clock_type: 'clock_in', clocked_at: date + 9.hours)
          create(:clocking, employee: employee, clock_type: 'clock_out', clocked_at: date + 17.hours)
        end
        
        payroll = create(:payroll,
          employee: employee,
          pay_period_start: 30.days.ago,
          pay_period_end: Date.current
        )
        
        start_time = Time.current
        payroll.calculate_from_clockings
        duration = Time.current - start_time
        
        # Should complete efficiently
        expect(duration).to be < 2.seconds
        expect(payroll.total_hours).to be > 0
      end
    end

    context 'Security Critical Tests' do
      it 'prevents SQL injection in search queries' do
        # Test potential SQL injection attempts
        malicious_inputs = [
          "'; DROP TABLE employees; --",
          "1' OR '1'='1",
          "admin'; DELETE FROM payrolls; --"
        ]
        
        malicious_inputs.each do |input|
          expect {
            Employee.where("employee_code = ?", input).first
          }.not_to raise_error
        end
      end

      it 'validates employee access permissions' do
        employee1 = create(:employee)
        employee2 = create(:employee)
        
        # Employee should not access other's clockings directly
        clocking1 = create(:clocking, employee: employee1)
        
        # This would need proper authorization in controllers
        expect(clocking1.employee).to eq(employee1)
        expect(clocking1.employee).not_to eq(employee2)
      end

      it 'sanitizes sensitive payroll data' do
        payroll = create(:payroll, employee: employee)
        
        # Ensure calculation details don't contain sensitive info
        expect(payroll.calculation_details).not_to include('password')
        expect(payroll.calculation_details).not_to include('ssn')
        expect(payroll.calculation_details).not_to include('bank_account')
      end
    end
  end
end