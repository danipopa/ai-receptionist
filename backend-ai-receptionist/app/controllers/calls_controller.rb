class CallsController < ApplicationController
  before_action :set_call, only: [:show, :update, :destroy]

  # GET /api/calls
  def index
    @calls = Call.all.order(created_at: :desc)
    render json: @calls
  end

  # GET /api/calls/:id
  def show
    render json: @call
  end

  # POST /api/calls
  def create
    @call = Call.new(call_params)
    
    if @call.save
      # Notify AI services about new call
      notify_ai_services(@call)
      render json: @call, status: :created
    else
      render json: @call.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/calls/:id
  def update
    if @call.update(call_params)
      render json: @call
    else
      render json: @call.errors, status: :unprocessable_entity
    end
  end

  # DELETE /api/calls/:id
  def destroy
    @call.destroy
    head :no_content
  end

  # POST /api/calls/events
  def events
    event_type = params[:event_type]
    data = params[:data]
    
    case event_type
    when 'call_start'
      handle_call_start(data)
    when 'call_end'
      handle_call_end(data)
    when 'transfer_request'
      handle_transfer_request(data)
    else
      render json: { error: 'Unknown event type' }, status: :bad_request
      return
    end
    
    render json: { status: 'event_processed' }
  end

  # POST /api/calls/:id/transfer
  def transfer
    transfer_to = params[:transfer_to]
    
    if @call.transfer_to(transfer_to)
      render json: { status: 'transfer_initiated', transfer_to: transfer_to }
    else
      render json: { error: 'Transfer failed' }, status: :unprocessable_entity
    end
  end

  # GET /api/calls/:id/transcript
  def transcript
    render json: { 
      call_id: @call.id,
      transcript: @call.transcript,
      messages: @call.call_messages.order(:created_at)
    }
  end

  private

  def set_call
    @call = Call.find(params[:id])
  end

  def call_params
    params.require(:call).permit(:phone_number, :status, :duration, :notes, :caller_name)
  end

  def notify_ai_services(call)
    # Notify AI Engine about new call
    AiEngineService.new.notify_new_call(call)
    
    # Notify FreeSWITCH service
    FreeswitchService.new.setup_call(call)
  end

  def handle_call_start(data)
    call = Call.find_or_create_by(
      external_call_id: data['call_id'],
      phone_number: data['phone_number']
    ) do |c|
      c.status = 'active'
      c.started_at = Time.parse(data['timestamp']) if data['timestamp']
    end
    
    # Log call start event
    call.call_events.create!(
      event_type: 'call_start',
      event_data: data,
      timestamp: Time.current
    )
  end

  def handle_call_end(data)
    call = Call.find_by(external_call_id: data['call_id'])
    
    if call
      call.update!(
        status: 'completed',
        duration: data['duration'],
        ended_at: Time.current
      )
      
      # Log call end event
      call.call_events.create!(
        event_type: 'call_end',
        event_data: data,
        timestamp: Time.current
      )
    end
  end

  def handle_transfer_request(data)
    call = Call.find_by(external_call_id: data['call_id'])
    
    if call
      call.call_events.create!(
        event_type: 'transfer_request',
        event_data: data,
        timestamp: Time.current
      )
      
      # Initiate transfer process
      call.initiate_transfer(data['transfer_to'])
    end
  end
end