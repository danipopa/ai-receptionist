#!/usr/bin/env ruby

# Test script for AI Chat endpoint
# Usage: ruby test_ai_chat.rb

require 'net/http'
require 'json'
require 'uri'

class AiChatTester
  def initialize(base_url = 'http://localhost:3000', api_key = 'your-api-key-here')
    @base_url = base_url
    @api_key = api_key
  end

  def test_chat_endpoint
    puts "Testing AI Chat Endpoint..."
    puts "=" * 50

    # Test data
    test_data = {
      message: "Hello, I'd like to know about your business hours",
      phone_number_id: 1,
      session_id: "test_session_#{Time.now.to_i}",
      context: {
        conversation_history: [],
        customer_id: nil,
        metadata: {
          source: "test_script"
        }
      }
    }

    response = make_request(test_data)
    
    if response
      puts "✅ Success!"
      puts "Response: #{response['response']}"
      puts "Session ID: #{response['session_id']}"
      puts "Status: #{response['status']}"
    else
      puts "❌ Request failed"
    end

    puts "\n" + "=" * 50
    puts "Testing conversation continuity..."
    
    # Test conversation continuity
    if response && response['session_id']
      test_followup(response['session_id'])
    end
  end

  def test_followup(session_id)
    test_data = {
      message: "What services do you offer?",
      phone_number_id: 1,
      session_id: session_id,
      context: {
        conversation_history: [
          { role: "user", message: "Hello, I'd like to know about your business hours" },
          { role: "assistant", message: "Hello! Our business hours are..." }
        ],
        customer_id: nil,
        metadata: {
          source: "test_script_followup"
        }
      }
    }

    response = make_request(test_data)
    
    if response
      puts "✅ Follow-up successful!"
      puts "Response: #{response['response']}"
    else
      puts "❌ Follow-up failed"
    end
  end

  def test_authentication
    puts "Testing authentication..."
    
    # Test without API key
    response = make_request({}, headers: {})
    puts response ? "❌ Should have failed without API key" : "✅ Correctly rejected request without API key"
    
    # Test with invalid API key
    response = make_request({}, headers: { 'Authorization' => 'Bearer invalid-key' })
    puts response ? "❌ Should have failed with invalid API key" : "✅ Correctly rejected invalid API key"
  end

  private

  def make_request(data, headers: nil)
    uri = URI("#{@base_url}/api/v1/ai/chat")
    
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri)
    
    # Set headers
    default_headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{@api_key}",
      'X-API-Key' => @api_key
    }
    
    headers = headers || default_headers
    headers.each { |key, value| request[key] = value }
    
    # Set body
    request.body = data.to_json unless data.empty?
    
    begin
      response = http.request(request)
      
      puts "Status: #{response.code}"
      puts "Body: #{response.body}"
      
      if response.code.to_i < 400
        JSON.parse(response.body)
      else
        puts "Error: #{response.body}"
        nil
      end
    rescue => e
      puts "Request failed: #{e.message}"
      nil
    end
  end
end

# Configuration
BASE_URL = ENV['API_BASE_URL'] || 'http://localhost:3000'
API_KEY = ENV['API_KEY'] || 'test-api-key'

puts "AI Chat Endpoint Tester"
puts "Base URL: #{BASE_URL}"
puts "API Key: #{API_KEY[0..10]}..." if API_KEY.length > 10

# Run tests
tester = AiChatTester.new(BASE_URL, API_KEY)

puts "\n1. Testing Authentication"
tester.test_authentication

puts "\n2. Testing Chat Endpoint"
tester.test_chat_endpoint

puts "\nDone! Remember to:"
puts "- Set API_KEY environment variable with a valid key"
puts "- Ensure the backend server is running"
puts "- Create a phone number record with ID 1 in your database"