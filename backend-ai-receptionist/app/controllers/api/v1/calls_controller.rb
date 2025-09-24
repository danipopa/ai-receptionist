class Api::V1::CallsController < ApplicationController
  before_action :set_call, only: [:show, :update, :destroy]
  
  def index
    @calls = Call.includes(:phone_number, :customer, :call_transcripts, :ai_responses)
                 .recent
                 .page(params[:page])
    
    render json: {
      data: @calls.map { |call| call_json(call) },
      meta: pagination_meta(@calls)
    }
  end
  
  def show
    render json: { data: call_json(@call, include_details: true) }
  end
  
  def create
    @call = Call.new(call_params)
    
    if @call.save
      render json: { data: call_json(@call) }, status: :created
    else
      render json: { errors: @call.errors }, status: :unprocessable_entity
    end
  end
  
  def update
    if @call.update(call_params)
      render json: { data: call_json(@call) }
    else
      render json: { errors: @call.errors }, status: :unprocessable_entity
    end
  end
  
  def destroy
    @call.destroy
    head :no_content
  end
  
  # GET /api/v1/calls/:id/transcript
  def transcript
    @call = Call.find(params[:id])
    @transcripts = @call.call_transcripts.chronological
    
    render json: {
      data: @transcripts.map { |transcript| transcript_json(transcript) }
    }
  end
  
  # POST /api/v1/calls/:id/transcript
  def add_transcript
    @call = Call.find(params[:id])
    @transcript = @call.call_transcripts.build(transcript_params)
    
    if @transcript.save
      render json: { data: transcript_json(@transcript) }, status: :created
    else
      render json: { errors: @transcript.errors }, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_call
    @call = Call.find(params[:id])
  end
  
  def call_params
    params.require(:call).permit(:phone_number_id, :caller_phone, :status, :started_at, :ended_at, :summary, :sentiment, tags: [])
  end
  
  def transcript_params
    params.require(:transcript).permit(:content, :speaker, :timestamp, :confidence_score, metadata: {})
  end
  
  def call_json(call, include_details: false)
    json = {
      id: call.id,
      caller_phone: call.caller_phone,
      status: call.status,
      duration: call.formatted_duration,
      summary: call.summary,
      sentiment: call.sentiment,
      tags: call.tags,
      started_at: call.started_at,
      ended_at: call.ended_at,
      created_at: call.created_at,
      updated_at: call.updated_at
    }
    
    if call.phone_number
      json[:phone_number] = {
        id: call.phone_number.id,
        number: call.phone_number.formatted_number,
        label: call.phone_number.label
      }
      json[:customer] = {
        id: call.customer.id,
        name: call.customer.name,
        company: call.customer.company
      }
    end
    
    if include_details
      json[:transcripts] = call.call_transcripts.chronological.map { |t| transcript_json(t) }
      json[:ai_responses] = call.ai_responses.map { |r| ai_response_json(r) }
    end
    
    json
  end
  
  def transcript_json(transcript)
    {
      id: transcript.id,
      content: transcript.content,
      speaker: transcript.speaker,
      timestamp: transcript.timestamp,
      confidence_score: transcript.confidence_score,
      metadata: transcript.metadata,
      created_at: transcript.created_at
    }
  end
  
  def ai_response_json(response)
    {
      id: response.id,
      prompt: response.prompt,
      response: response.response,
      processing_time: response.processing_time,
      created_at: response.created_at
    }
  end
end