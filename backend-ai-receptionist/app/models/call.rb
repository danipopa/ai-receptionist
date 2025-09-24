class Call < ApplicationRecord
  belongs_to :phone_number
  has_many :ai_responses, dependent: :destroy
  has_many :call_transcripts, dependent: :destroy
  
  validates :phone_number, presence: true
  validates :status, inclusion: { in: %w[pending active completed failed] }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :today, -> { where(created_at: Date.current.beginning_of_day..Date.current.end_of_day) }
  
  def duration_in_seconds
    return 0 unless started_at && ended_at
    (ended_at - started_at).to_i
  end
  
  def formatted_duration
    return '0:00' unless started_at && ended_at
    total_seconds = duration_in_seconds
    minutes = total_seconds / 60
    seconds = total_seconds % 60
    "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
  end
  
  def customer
    phone_number.customer
  end
end