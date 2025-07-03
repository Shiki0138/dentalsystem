class BetaFeedback < ApplicationRecord
  belongs_to :clinic, optional: true
  
  validates :message, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_page, ->(page) { where(page: page) }
end
