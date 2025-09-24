class CallEvent < ApplicationRecord
  belongs_to :call

  validates :event_type, presence: true
  validates :timestamp, presence: true

  scope :by_type, ->(type) { where(event_type: type) }
  scope :recent, -> { order(timestamp: :desc) }

  def formatted_timestamp
    timestamp.strftime("%Y-%m-%d %H:%M:%S")
  end
end