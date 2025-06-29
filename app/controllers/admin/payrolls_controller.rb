class Admin::PayrollsController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_payroll, only: [:show, :edit, :update, :approve, :mark_as_paid]
  
  def index
    @month = params[:month].present? ? Date.parse(params[:month]) : Date.current
    @pay_period_start = @month.beginning_of_month
    @pay_period_end = @month.end_of_month
    
    @payrolls = Payroll.includes(:employee)
                       .for_period(@pay_period_start, @pay_period_end)
                       .order('employees.last_name', 'employees.first_name')
    
    @summary = calculate_summary(@payrolls)
  end
  
  def show
    @clockings = @payroll.employee.clockings
                         .for_period(@payroll.pay_period_start, @payroll.pay_period_end)
                         .order(:clocked_at)
  end
  
  def edit
  end
  
  def update
    if @payroll.update(payroll_params.merge(
      calculation_details: @payroll.calculation_details.merge('manual_override' => true)
    ))
      redirect_to admin_payroll_path(@payroll), notice: '給与情報を更新しました'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def approve
    if @payroll.approve!(current_user.employee)
      respond_to do |format|
        format.html { redirect_to admin_payrolls_path, notice: '給与を承認しました' }
        format.turbo_stream {
          render turbo_stream: [
            turbo_stream.replace(@payroll, partial: 'payroll_row', locals: { payroll: @payroll }),
            turbo_stream.update('flash', partial: 'shared/flash', locals: { notice: '給与を承認しました' })
          ]
        }
      end
    else
      redirect_to admin_payrolls_path, alert: '給与の承認に失敗しました'
    end
  end
  
  def mark_as_paid
    if @payroll.mark_as_paid!
      respond_to do |format|
        format.html { redirect_to admin_payrolls_path, notice: '支払い完了を記録しました' }
        format.turbo_stream {
          render turbo_stream: [
            turbo_stream.replace(@payroll, partial: 'payroll_row', locals: { payroll: @payroll }),
            turbo_stream.update('flash', partial: 'shared/flash', locals: { notice: '支払い完了を記録しました' })
          ]
        }
      end
    else
      redirect_to admin_payrolls_path, alert: '支払い完了の記録に失敗しました'
    end
  end
  
  def calculate_all
    month = params[:month].present? ? Date.parse(params[:month]) : Date.current
    
    MonthlyPayrollJob.perform_later(month.to_s)
    
    redirect_to admin_payrolls_path(month: month), notice: '給与計算を開始しました'
  end
  
  def export
    @month = params[:month].present? ? Date.parse(params[:month]) : Date.current
    @pay_period_start = @month.beginning_of_month
    @pay_period_end = @month.end_of_month
    
    @payrolls = Payroll.includes(:employee)
                       .for_period(@pay_period_start, @pay_period_end)
                       .order('employees.last_name', 'employees.first_name')
    
    respond_to do |format|
      format.csv { send_data generate_csv(@payrolls), filename: "payroll_#{@month.strftime('%Y%m')}.csv" }
    end
  end
  
  private
  
  def authenticate_admin!
    redirect_to root_path unless current_user&.admin?
  end
  
  def set_payroll
    @payroll = Payroll.find(params[:id])
  end
  
  def payroll_params
    params.require(:payroll).permit(
      :total_hours, :regular_hours, :overtime_hours, :holiday_hours,
      :base_pay, :overtime_pay, :holiday_pay, :allowances, :deductions
    )
  end
  
  def calculate_summary(payrolls)
    {
      total_employees: payrolls.map(&:employee_id).uniq.count,
      total_gross: payrolls.sum(&:gross_pay),
      total_net: payrolls.sum(&:net_pay),
      total_deductions: payrolls.sum(&:deductions),
      draft_count: payrolls.draft.count,
      approved_count: payrolls.approved.count,
      paid_count: payrolls.paid.count
    }
  end
  
  def generate_csv(payrolls)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << [
        '従業員コード', '氏名', '雇用形態', '勤務時間', '通常時間', '残業時間',
        '休日時間', '基本給', '残業手当', '休日手当', '諸手当', '控除額',
        '総支給額', '差引支給額', 'ステータス'
      ]
      
      payrolls.each do |payroll|
        csv << [
          payroll.employee.employee_code,
          payroll.employee.full_name,
          I18n.t("employment_type.#{payroll.employee.employment_type}"),
          payroll.total_hours,
          payroll.regular_hours,
          payroll.overtime_hours,
          payroll.holiday_hours,
          payroll.base_pay,
          payroll.overtime_pay,
          payroll.holiday_pay,
          payroll.allowances,
          payroll.deductions,
          payroll.gross_pay,
          payroll.net_pay,
          I18n.t("payroll_status.#{payroll.status}")
        ]
      end
    end
  end
end