# == Schema Information
#
# Table name: patients
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  name_kana       :string
#  email           :string
#  phone           :string           not null
#  birth_date      :date
#  address         :text
#  insurance_info  :text
#  notes           :text
#  line_user_id    :string
#  demo_data       :boolean          default(FALSE)
#  patient_number  :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class Patient < ApplicationRecord
  include Discard::Model
  include Cacheable
  require Rails.root.join('config', 'demo_mode')

  has_many :appointments, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
  validates :phone, presence: true, format: { with: /\A[\d\-\+\(\)]+\z/ }, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  # ステータス管理
  enum status: { active: 'active', inactive: 'inactive', suspended: 'suspended' }
  enum gender: { male: 'male', female: 'female', other: 'other' }

  # Callbacks
  before_validation :normalize_phone
  before_create :generate_patient_number

  scope :search_by_name, ->(query) { where("name ILIKE ? OR name_kana ILIKE ?", "%#{query}%", "%#{query}%") }
  scope :search_by_phone, ->(phone) { where("phone LIKE ?", "%#{phone.gsub(/[^\d]/, '')}%") }
  scope :active, -> { where(status: 'active') }
  scope :due_for_recall, -> { where('next_recall_date <= ?', Date.current) }
  scope :birthday_this_month, -> { where('EXTRACT(month FROM birth_date) = ?', Date.current.month) }
  
  # デモモード関連スコープ
  scope :demo_data, -> { where("name LIKE ?", "#{DemoMode.demo_prefix}%") }
  scope :production_data, -> { where("name NOT LIKE ?", "#{DemoMode.demo_prefix}%") }
  scope :safe_for_demo, -> { DemoMode.enabled? ? demo_data : all }

  # 患者検索（名前・電話番号・メールアドレス） - パフォーマンス最適化版
  def self.search(query)
    return none if query.blank?

    query = query.strip
    
    # 電話番号の場合 - インデックス活用
    if query.match?(/\A[\d\-\+\(\)]+\z/)
      normalized_phone = query.gsub(/[^\d]/, '')
      where("phone LIKE ?", "%#{normalized_phone}%")
        .order(:name)
        .limit(50)
    else
      # 名前・カナ・メールアドレスで検索 - GINインデックス活用
      includes(:appointments)
        .where(
          "name ILIKE :query OR name_kana ILIKE :query OR email ILIKE :query",
          query: "%#{query}%"
        )
        .order(:name)
        .limit(50)
    end
  end

  # 次の予約を取得
  def next_appointment
    appointments.upcoming.order(:appointment_date).first
  end

  # 最後の診療日を取得
  def last_visit
    appointments.where(status: ['visited', 'done', 'paid'])
               .order(:appointment_date)
               .last&.appointment_date
  end

  # 重複患者候補を検出（簡素化版）
  def self.find_duplicates
    patients_with_same_phone = Patient.group(:phone).having('COUNT(*) > 1').pluck(:phone)
    
    duplicates = []
    patients_with_same_phone.each do |phone|
      duplicate_group = Patient.where(phone: phone).order(:created_at)
      duplicates << duplicate_group if duplicate_group.count > 1
    end
    
    duplicates
  end

  # 表示用の名前（カナ併記）
  def display_name
    if name_kana.present?
      "#{name} (#{name_kana})"
    else
      name
    end
  end
  
  # デモデータかどうか判定
  def demo_data?
    return false unless DemoMode.enabled?
    name&.start_with?(DemoMode.demo_prefix)
  end
  
  # デモモードでの安全な操作チェック
  def safe_for_demo_operation?(operation)
    return true unless DemoMode.enabled?
    
    case operation
    when :delete, :destroy
      demo_data? # デモデータのみ削除可能
    when :update, :edit
      demo_data? # デモデータのみ編集可能
    else
      true # その他の操作は許可
    end
  end

  # 年齢計算
  def age
    return nil if birth_date.nil?
    
    age = Date.current.year - birth_date.year
    age -= 1 if Date.current < birth_date + age.years
    age
  end

  # 患者マージ機能（簡素化版）
  def merge_with!(other_patient)
    return false if other_patient == self

    transaction do
      # Move appointments to this patient
      other_patient.appointments.update_all(patient_id: id)
      
      # Mark other patient as inactive
      other_patient.update!(status: 'inactive')
    end

    true
  end

  private

  def normalize_phone
    return unless phone

    # Remove all non-numeric characters except + at the beginning
    self.phone = phone.gsub(/[^\d+]/, '').gsub(/(?<!^)\+/, '')
  end

  def generate_patient_number
    return if patient_number.present?

    self.patient_number = loop do
      number = "P#{Date.current.strftime('%Y%m')}#{sprintf('%04d', rand(10000))}"
      break number unless Patient.exists?(patient_number: number)
    end
  end
end