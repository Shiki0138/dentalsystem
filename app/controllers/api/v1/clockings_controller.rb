class Api::V1::ClockingsController < ApplicationController
  before_action :authenticate_employee!
  before_action :set_employee
  before_action :set_clocking, only: [:show, :update, :destroy]

  def index
    @clockings = @employee.clockings
                          .for_period(start_date, end_date)
                          .order(clocked_at: :desc)
    
    render json: {
      clockings: @clockings.map { |c| clocking_json(c) },
      summary: calculate_summary(@clockings)
    }
  end

  def create
    @clocking = @employee.clockings.build(clocking_params)
    
    # Set GPS location if provided
    if params[:location].present?
      @clocking.latitude = params[:location][:latitude]
      @clocking.longitude = params[:location][:longitude]
      @clocking.location_accuracy = params[:location][:accuracy]
    end
    
    # Set device info
    @clocking.device_type = detect_device_type
    @clocking.ip_address = request.remote_ip
    
    if @clocking.save
      render json: {
        success: true,
        clocking: clocking_json(@clocking),
        message: clock_message(@clocking)
      }, status: :created
    else
      render json: {
        success: false,
        errors: @clocking.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def show
    render json: { clocking: clocking_json(@clocking) }
  end

  def update
    if @clocking.update(clocking_params.merge(
      manual_entry: true,
      edited_by: current_employee,
      edited_at: Time.current
    ))
      render json: {
        success: true,
        clocking: clocking_json(@clocking)
      }
    else
      render json: {
        success: false,
        errors: @clocking.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def destroy
    @clocking.destroy
    render json: { success: true }
  end

  def status
    latest = @employee.clockings.latest_for_employee(@employee.id)
    
    render json: {
      status: @employee.current_clocking_status,
      last_clocking: latest ? clocking_json(latest) : nil,
      clocked_in: @employee.clocked_in?,
      on_break: @employee.on_break?
    }
  end

  def today
    @clockings = @employee.clockings.for_date(Date.current).order(:clocked_at)
    
    render json: {
      date: Date.current,
      clockings: @clockings.map { |c| clocking_json(c) },
      summary: calculate_daily_summary(@clockings)
    }
  end

  private

  def authenticate_employee!
    # TODO: Implement with Devise or JWT
    head :unauthorized unless current_employee
  end

  def current_employee
    # TODO: Get from session/token
    @current_employee ||= Employee.find_by(id: params[:employee_id])
  end

  def set_employee
    @employee = current_employee
    # Allow admin to view other employees
    if params[:employee_id].present? && current_employee.admin?
      @employee = Employee.find(params[:employee_id])
    end
  end

  def set_clocking
    @clocking = @employee.clockings.find(params[:id])
  end

  def clocking_params
    params.require(:clocking).permit(:clock_type, :clocked_at, :notes)
  end

  def start_date
    params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current.beginning_of_month
  end

  def end_date
    params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current.end_of_month
  end

  def detect_device_type
    user_agent = request.user_agent.to_s.downcase
    
    if user_agent.include?('mobile') || user_agent.include?('android') || user_agent.include?('iphone')
      'mobile'
    else
      'web'
    end
  end

  def clocking_json(clocking)
    {
      id: clocking.id,
      clock_type: clocking.clock_type,
      clocked_at: clocking.clocked_at,
      formatted_time: clocking.clocked_at.strftime('%H:%M'),
      formatted_date: clocking.clocked_at.strftime('%Y-%m-%d'),
      notes: clocking.notes,
      location: {
        latitude: clocking.latitude,
        longitude: clocking.longitude,
        accuracy: clocking.location_accuracy,
        within_range: clocking.within_office_range?
      },
      device_type: clocking.device_type,
      manual_entry: clocking.manual_entry,
      edited_by: clocking.edited_by&.full_name,
      edited_at: clocking.edited_at
    }
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

  def calculate_summary(clockings)
    total_minutes = 0
    break_minutes = 0
    
    # Calculate worked hours
    work_pairs = []
    clockings.each do |c|
      if c.clock_in?
        work_pairs << { start: c.clocked_at, end: nil }
      elsif c.clock_out? && work_pairs.last && work_pairs.last[:end].nil?
        work_pairs.last[:end] = c.clocked_at
      end
    end
    
    work_pairs.each do |pair|
      if pair[:end]
        total_minutes += ((pair[:end] - pair[:start]) / 60).to_i
      end
    end
    
    {
      total_hours: (total_minutes / 60.0).round(2),
      total_days: clockings.clock_ins.map { |c| c.clocked_at.to_date }.uniq.count
    }
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