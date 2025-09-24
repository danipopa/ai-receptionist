class CallTranscript < ApplicationRecord
  belongs_to :phone_number
  
  validates :caller_id, presence: true
  validates :call_status, inclusion: { in: %w[incoming outgoing missed completed] }
  
  scope :completed, -> { where(call_status: 'completed') }
  scope :recent, -> { order(started_at: :desc) }
  
  def duration_in_minutes
    return 0 unless call_duration
    (call_duration / 60.0).round(2)
  end
end