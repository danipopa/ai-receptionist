class Api::V1::AiController < ApplicationController
  before_action :validate_chat_params, only: [:chat]
  before_action :load_phone_number, only: [:chat]
  before_action :load_customer, only: [:chat]
  
  def chat
    begin
      # Initialize AI service
      ai_service = AiEngineService.new
      
      # Get or create conversation session
      session_id = params[:session_id] || generate_session_id
      
      # Build context for AI
      context = build_ai_context
      
      # Process the message using the configured AI provider
      result = process_chat_message(ai_service, context)
      
      if result&.dig('text_response')
        # Store the conversation in database
        store_conversation(session_id, params[:message], result['text_response'])
        
        render json: {
          response: result['text_response'],
          session_id: session_id,
          status: 'success'
        }, status: :ok
      else
        render json: {
          response: 'I apologize, but I encountered an issue processing your request. Please try again.',
          session_id: session_id,
          status: 'error'
        }, status: :ok
      end
      
    rescue => e
      Rails.logger.error "AI Chat error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      render json: {
        response: 'I apologize, but I\'m experiencing technical difficulties. Please try again.',
        session_id: params[:session_id] || generate_session_id,
        status: 'error'
      }, status: :internal_server_error
    end
  end
  
  private
  
  def validate_chat_params
    unless params[:message].present?
      render json: {
        error: 'Message is required',
        status: 'error'
      }, status: :bad_request
      return
    end
    
    unless params[:phone_number_id].present?
      render json: {
        error: 'Phone number ID is required',
        status: 'error'
      }, status: :bad_request
      return
    end
  end
  
  def load_phone_number
    @phone_number = PhoneNumber.find_by(id: params[:phone_number_id])
    
    unless @phone_number
      render json: {
        error: 'Phone number not found',
        status: 'error'
      }, status: :not_found
      return
    end
  end
  
  def load_customer
    if params[:context] && params[:context][:customer_id]
      @customer = Customer.find_by(id: params[:context][:customer_id])
    end
  end
  
  def build_ai_context
    context = {
      phone_number: @phone_number,
      customer: @customer,
      conversation_history: extract_conversation_history,
      faqs: @phone_number.faqs.limit(10),
      metadata: params[:context]&.dig(:metadata) || {}
    }
    
    context
  end
  
  def extract_conversation_history
    history = params[:context]&.dig(:conversation_history) || []
    
    # Convert to standard format
    history.map do |msg|
      {
        role: msg[:role] == 'assistant' ? 'assistant' : 'user',
        content: msg[:message] || msg[:content] || ''
      }
    end
  end
  
  def process_chat_message(ai_service, context)
    # Create a temporary call object for the AI service
    # This maintains compatibility with existing AI provider interface
    temp_call = create_temp_call_object(context)
    
    # Add conversation history to the call
    add_conversation_history_to_call(temp_call, context[:conversation_history])
    
    # Add the current message
    temp_call.add_message('user', params[:message])
    
    # Generate AI response using the provider
    if ai_service.respond_to?(:provider) && ai_service.send(:instance_variable_get, :@provider)
      # Use new provider system
      provider = ai_service.send(:instance_variable_get, :@provider)
      messages = provider.send(:build_conversation_context, temp_call)
      response_text = provider.send(:generate_text_response, messages)
      
      {
        'text_response' => response_text,
        'transcript' => params[:message]
      }
    else
      # Fallback to original implementation would go here
      # For now, generate a simple response
      {
        'text_response' => generate_fallback_response(context),
        'transcript' => params[:message]
      }
    end
  end
  
  def create_temp_call_object(context)
    # Create a temporary call-like object that works with our AI providers
    temp_call = OpenStruct.new(
      id: "chat_#{Time.current.to_i}",
      phone_number_record: context[:phone_number],
      customer: context[:customer],
      call_messages: [],
      ai_session_id: params[:session_id]
    )
    
    # Add methods that the AI providers expect
    def temp_call.add_message(sender, content)
      message = OpenStruct.new(
        sender: sender,
        content: content,
        created_at: Time.current
      )
      self.call_messages << message
    end
    
    def temp_call.update(attributes)
      attributes.each { |key, value| self.send("#{key}=", value) if self.respond_to?("#{key}=") }
    end
    
    temp_call
  end
  
  def add_conversation_history_to_call(call, history)
    history.each do |msg|
      call.add_message(msg[:role], msg[:content])
    end
  end
  
  def generate_fallback_response(context)
    customer_name = context[:customer]&.name
    business_name = context[:phone_number]&.business_name || 'our business'
    
    greeting = customer_name ? "Hello #{customer_name}" : "Hello"
    
    "#{greeting}! Thank you for contacting #{business_name}. I'm here to help you. How can I assist you today?"
  end
  
  def store_conversation(session_id, user_message, ai_response)
    # Create or find a call record for this chat session
    call = find_or_create_chat_call(session_id)
    
    # Store both messages
    call.add_message('user', user_message)
    call.add_message('assistant', ai_response)
    
    # Update call summary if needed
    update_call_summary(call)
  end
  
  def find_or_create_chat_call(session_id)
    # Look for existing call with this session ID
    call = Call.find_by(external_call_id: "chat_#{session_id}")
    
    unless call
      call = Call.create!(
        external_call_id: "chat_#{session_id}",
        phone_number_id: @phone_number.id,
        customer_id: @customer&.id,
        caller_phone: @customer&.phone || 'web_chat',
        status: 'active',
        started_at: Time.current,
        summary: 'Web chat conversation'
      )
    end
    
    call
  end
  
  def update_call_summary(call)
    message_count = call.call_messages.count
    if message_count > 2 && (message_count % 10 == 0) # Update summary every 10 messages
      last_messages = call.call_messages.order(:created_at).last(10)
      summary = "Chat conversation with #{message_count} messages. Recent topics: " +
                last_messages.map(&:content).last(3).join('; ')
      call.update(summary: summary.truncate(255))
    end
  end
  
  def generate_session_id
    "web_chat_#{Time.current.to_i}_#{SecureRandom.hex(8)}"
  end
end