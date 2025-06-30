class User < ApplicationRecord
  include Discard::Model

  # Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :appointments, foreign_key: :staff_member_id, dependent: :nullify
  has_many :clockings, dependent: :destroy
  has_many :payrolls, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :role, presence: true, inclusion: { in: %w[admin doctor hygienist receptionist] }
  validates :phone, format: { with: /\A[\d\-\+\(\)]+\z/ }, allow_blank: true

  # Scopes
  scope :active, -> { kept }
  scope :by_role, ->(role) { where(role: role) }
  scope :doctors, -> { where(role: 'doctor') }
  scope :staff, -> { where(role: ['hygienist', 'receptionist']) }

  # Callbacks
  before_validation :normalize_phone
  after_create :setup_two_factor_authentication

  # Role methods
  def admin?
    role == 'admin'
  end

  def doctor?
    role == 'doctor'
  end

  def hygienist?
    role == 'hygienist'
  end

  def receptionist?
    role == 'receptionist'
  end

  def staff?
    hygienist? || receptionist?
  end

  def medical_staff?
    doctor? || hygienist?
  end

  # 2FA methods
  def two_factor_enabled?
    otp_required_for_login?
  end

  def enable_two_factor!
    self.otp_required_for_login = true
    self.otp_secret = User.generate_otp_secret
    save!
  end

  def disable_two_factor!
    self.otp_required_for_login = false
    self.otp_secret = nil
    save!
  end

  def provisioning_uri(issuer = nil)
    require 'rotp'
    issuer ||= 'DentalSystem'
    ROTP::TOTP.new(otp_secret, issuer: issuer).provisioning_uri(email)
  end

  def qr_code_uri
    require 'rqrcode'
    qrcode = RQRCode::QRCode.new(provisioning_uri)
    qrcode.as_svg(
      offset: 0,
      color: '000',
      shape_rendering: 'crispEdges',
      module_size: 6,
      standalone: true
    )
  end

  # Working hours
  def working_today?
    clockings.today.exists?
  end

  def current_shift
    clockings.today.where(clock_out: nil).first
  end

  def clock_in!
    return false if working_today?

    clockings.create!(
      clock_in: Time.current,
      date: Date.current
    )
  end

  def clock_out!
    current_shift&.update!(clock_out: Time.current)
  end

  private

  def normalize_phone
    return unless phone

    self.phone = phone.gsub(/[^\d+]/, '').gsub(/(?<!^)\+/, '')
  end

  def setup_two_factor_authentication
    return unless Rails.env.production?

    # Auto-enable 2FA for admin and doctor roles
    if admin? || doctor?
      enable_two_factor!
    end
  end
end