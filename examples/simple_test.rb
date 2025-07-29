#!/usr/bin/env ruby

require_relative '../lib/langgraph_rb'

def simple_workflow_test
  puts "=== Simple LangGraphRB Test ==="
  
  # Create a simple linear workflow
  graph = LangGraphRB::Graph.new do
    node :start_process do |state|
      puts "🚀 Starting process with input: #{state[:input]}"
      { 
        step: 1, 
        message: "Process started",
        processed_input: state[:input]&.upcase
      }
    end

    node :analyze_data do |state|
      puts "🔍 Analyzing: #{state[:processed_input]}"
      sleep(0.1)  # Simulate work
      
      analysis_result = case state[:processed_input]&.downcase
                       when /hello/
                         'greeting_detected'
                       when /help/
                         'help_request' 
                       when /goodbye/
                         'farewell_detected'
                       else
                         'general_input'
                       end
      
      {
        step: 2,
        analysis: analysis_result,
        message: "Analysis complete: #{analysis_result}"
      }
    end

    node :generate_response do |state|
      puts "💭 Generating response for: #{state[:analysis]}"
      
      response = case state[:analysis]
                when 'greeting_detected'
                  "Hello! Nice to meet you!"
                when 'help_request'
                  "I'm here to help! What do you need assistance with?"
                when 'farewell_detected' 
                  "Goodbye! Have a great day!"
                else
                  "I understand. Tell me more about that."
                end
      
      {
        step: 3,
        final_response: response,
        message: "Response generated",
        completed: true
      }
    end

    node :generate_response_2 do |state|
      puts "💭 Generating response for: #{state[:analysis]}"
      {
        step: 4,
        final_response: "Response generated",
        message: "Response generated",
        completed: true
      } 
    end

    # Define simple linear flow
    set_entry_point :start_process
    edge :start_process, :analyze_data
    edge :analyze_data, :generate_response
    edge :analyze_data, :generate_response_2
    set_finish_point :generate_response
  end

  # Compile the graph
  graph.compile!
  
  puts "\n📊 Graph structure:"
  puts graph.to_mermaid
  puts

  # Test with different inputs
  test_inputs = [
    "Hello there!",
    "I need help",
    "Goodbye everyone",
    "Just a regular message"
  ]

  test_inputs.each_with_index do |input, i|
    puts "\n--- Test #{i + 1}: '#{input}' ---"
    
    result = graph.invoke({ input: input })
    
    puts "✅ Final response: #{result[:final_response]}"
    puts "   Steps completed: #{result[:step]}"
    puts "   Status: #{result[:completed] ? 'Complete' : 'Incomplete'}"
  end
  
  puts "\n✅ Simple workflow test completed!"
end

def conditional_routing_test
  puts "\n=== Conditional Routing Test ==="
  
  graph = LangGraphRB::Graph.new do
    node :router do |state|
      input = state[:input]&.to_s&.downcase || ""
      puts "🔄 Routing input: #{input}"
      
      {
        input_type: case input
                   when /urgent/, /emergency/
                     'urgent'
                   when /question/, /help/
                     'question'
                   when /feedback/, /complaint/
                     'feedback'
                   else
                     'general'
                   end,
        original_input: input
      }
    end

    node :handle_urgent do |state|
      puts "🚨 Handling urgent request"
      {
        response: "Your urgent request has been escalated to our priority team!",
        priority: "high"
      }
    end

    node :handle_question do |state|
      puts "❓ Handling question"
      {
        response: "Thank you for your question. Let me help you with that.",
        priority: "medium"
      }
    end

    node :handle_feedback do |state|
      puts "💬 Handling feedback"
      {
        response: "We appreciate your feedback and will review it carefully.",
        priority: "medium"
      }
    end

    node :handle_general do |state|
      puts "📝 Handling general request"
      {
        response: "Thank you for contacting us. We'll get back to you soon.",
        priority: "normal"
      }
    end

    # Set up routing
    set_entry_point :router
    
    conditional_edge :router, ->(state) { state[:input_type] }, {
      'urgent' => :handle_urgent,
      'question' => :handle_question,
      'feedback' => :handle_feedback,
      'general' => :handle_general
    }

    # All handlers go to finish
    set_finish_point :handle_urgent
    set_finish_point :handle_question  
    set_finish_point :handle_feedback
    set_finish_point :handle_general
  end

  graph.compile!
  
  puts "\n📊 Conditional routing graph:"
  puts graph.to_mermaid
  puts

  # Test different routing scenarios
  test_cases = [
    "URGENT: System is down!",
    "I have a question about your service",
    "I want to give some feedback",
    "Just saying hello"
  ]

  test_cases.each_with_index do |input, i|
    puts "\n--- Routing Test #{i + 1}: '#{input}' ---"
    
    result = graph.invoke({ input: input })
    
    puts "📋 Response: #{result[:response]}"
    puts "🎯 Priority: #{result[:priority]}"
  end
  
  puts "\n✅ Conditional routing test completed!"
end

def streaming_test
  puts "\n=== Streaming Execution Test ==="
  
  graph = LangGraphRB::Graph.new do
    node :step_1 do |state|
      puts "  ⚙️  Step 1: Initialize"
      sleep(0.3)
      { step: 1, data: "initialized", progress: 25 }
    end

    node :step_2 do |state|
      puts "  ⚙️  Step 2: Process"
      sleep(0.3)
      { step: 2, data: state[:data] + " -> processed", progress: 50 }
    end

    node :step_3 do |state|
      puts "  ⚙️  Step 3: Validate"
      sleep(0.3)
      { step: 3, data: state[:data] + " -> validated", progress: 75 }
    end

    node :step_4 do |state|
      puts "  ⚙️  Step 4: Finalize"
      sleep(0.3)
      { step: 4, data: state[:data] + " -> finalized", progress: 100 }
    end

    set_entry_point :step_1
    edge :step_1, :step_2
    edge :step_2, :step_3
    edge :step_3, :step_4
    set_finish_point :step_4
  end

  graph.compile!

  puts "📡 Streaming execution progress:"
  start_time = Time.now
  
  result = graph.stream({ input: "test_data" }) do |step_result|
    elapsed = (Time.now - start_time).round(2)
    puts "  📊 [#{elapsed}s] Step #{step_result[:step]}: #{step_result[:active_nodes]}"
    if step_result[:state][:progress]
      puts "      Progress: #{step_result[:state][:progress]}%"
    end
  end
  
  puts "\n🏁 Final result: #{result[:state][:data]}"
  puts "⏱️  Total time: #{(Time.now - start_time).round(2)}s"
  
  puts "\n✅ Streaming test completed!"
end

# Run tests
if __FILE__ == $0
  #simple_workflow_test
  conditional_routing_test
  #streaming_test
end 