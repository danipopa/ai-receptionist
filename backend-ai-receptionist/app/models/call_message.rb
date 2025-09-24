class CallMessage < ApplicationRecord
  belongs_to :call

  validates :role, inclusion: { in: %w[user assistant system] }
  validates :content, presence: true
  validates :timestamp, presence: true

  scope :by_role, ->(role) { where(role: role) }
  scope :user_messages, -> { where(role: 'user') }
  scope :assistant_messages, -> { where(role: 'assistant') }
  scope :chronological, -> { order(:timestamp) }

  def formatted_timestamp
    timestamp.strftime("%H:%M:%S")
  end
end