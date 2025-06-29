class ClockingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_employee
  before_action :set_clocking, only: [:show, :edit, :update, :destroy]
  
  def index
    @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @clockings = @employee.clockings.for_date(@date).order(:clocked_at)
    @summary = calculate_daily_summary(@clockings)
    @current_status = @employee.current_clocking_status
  end
  
  def new
    @clocking = @employee.clockings.build
    @current_status = @employee.current_clocking_status
    @last_clocking = @employee.clockings.order(clocked_at: :desc).first
  end
  
  def create
    @clocking = @employee.clockings.build(clocking_params)
    
    # Handle GPS location for mobile devices
    if params[:use_location] == 'true' && params[:latitude].present?
      @clocking.latitude = params[:latitude]
      @clocking.longitude = params[:longitude]
      @clocking.location_accuracy = params[:accuracy]
    end
    
    @clocking.device_type = detect_device_type
    @clocking.ip_address = request.remote_ip
    
    respond_to do |format|
      if @clocking.save
        format.html { redirect_to employee_clockings_path(@employee), notice: clock_message(@clocking) }
        format.turbo_stream {
          render turbo_stream: [
            turbo_stream.prepend("clockings", partial: "clocking", locals: { clocking: @clocking }),
            turbo_stream.update("status_display", partial: "status", locals: { employee: @employee }),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: clock_message(@clocking) })
          ]
        }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream {
          render turbo_stream: turbo_stream.update("clocking_form", partial: "form", locals: { clocking: @clocking })
        }
      end
    end
  end
  
  def show
  end
  
  def edit
  end
  
  def update
    @clocking.manual_entry = true
    @clocking.edited_by = current_user.employee
    @clocking.edited_at = Time.current
    
    if @clocking.update(clocking_params)
      redirect_to employee_clockings_path(@employee), notice: '打刻情報を更新しました'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @clocking.destroy
    redirect_to employee_clockings_path(@employee), notice: '打刻情報を削除しました'
  end
  
  private
  
  def set_employee
    @employee = current_user.employee
    # Allow admin to manage other employees
    if params[:employee_id].present? && current_user.admin?
      @employee = Employee.find(params[:employee_id])
    end
  end
  
  def set_clocking
    @clocking = @employee.clockings.find(params[:id])
  end
  
  def clocking_params
    params.require(:clocking).permit(:clock_type, :clocked_at, :notes)
  end
  
  def detect_device_type
    user_agent = request.user_agent.to_s.downcase
    
    if user_agent.include?('mobile') || user_agent.include?('android') || user_agent.include?('iphone')
      'mobile'
    else
      'web'
    end
  end
  
  def clock_message(clocking)
    case clocking.clock_type
    when 'clock_in'
      'おはようございます！出勤を記録しました。'
    when 'clock_out'
      'お疲れさまでした！退勤を記録しました。'
    when 'break_start'
      '休憩開始を記録しました。'
    when 'break_end'
      '休憩終了を記録しました。作業を再開してください。'
    end
  end
  
  def calculate_daily_summary(clockings)
    return { worked_hours: 0, break_hours: 0 } if clockings.empty?
    
    worked_minutes = 0
    break_minutes = 0
    
    clock_in = clockings.find(&:clock_in?)
    clock_out = clockings.find(&:clock_out?)
    
    if clock_in && clock_out
      worked_minutes = ((clock_out.clocked_at - clock_in.clocked_at) / 60).to_i
      
      # Calculate breaks
      break_pairs = []
      clockings.each do |c|
        if c.break_start?
          break_pairs << { start: c.clocked_at, end: nil }
        elsif c.break_end? && break_pairs.last && break_pairs.last[:end].nil?
          break_pairs.last[:end] = c.clocked_at
        end
      end
      
      break_pairs.each do |pair|
        if pair[:end]
          break_minutes += ((pair[:end] - pair[:start]) / 60).to_i
        end
      end
      
      worked_minutes -= break_minutes
    end
    
    {
      worked_hours: (worked_minutes / 60.0).round(2),
      break_hours: (break_minutes / 60.0).round(2),
      clock_in_time: clock_in&.clocked_at&.strftime('%H:%M'),
      clock_out_time: clock_out&.clocked_at&.strftime('%H:%M')
    }
  end
end