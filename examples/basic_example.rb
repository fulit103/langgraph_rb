#!/usr/bin/env ruby

require_relative '../lib/langgraph_rb'

# Example: Simple chatbot with conditional routing
def basic_example
  puts "=== Basic LangGraphRB Example ==="
  
  # Create a state with message history
  initial_state = LangGraphRB::State.new(
    { messages: [], step_count: 0 },
    { messages: LangGraphRB::State.add_messages }
  )

  # Create the graph
  graph = LangGraphRB::Graph.new(state_class: LangGraphRB::State) do
    # Define nodes
    node :receive_input do |state|
      puts "👤 User input received: #{state[:input]}"
      {
        messages: [{ role: 'user', content: state[:input] }],
        last_user_message: state[:input],
        step_count: (state[:step_count] || 0) + 1
      }
    end

    node :analyze_intent do |state|
      user_message = state[:last_user_message].to_s.downcase
      
      intent = case user_message
              when /hello|hi|hey/
                'greeting'
              when /bye|goodbye|exit/
                'farewell'
              when /help|assist/
                'help_request'
              when /weather/
                'weather_query'
              else
                'general_chat'
              end
      
      puts "🧠 Detected intent: #{intent}"
      
      {
        intent: intent,
        messages: [{ role: 'system', content: "Intent detected: #{intent}" }]
      }
    end

    node :handle_greeting do |state|
      response = "Hello! How can I help you today?"
      puts "🤖 Bot: #{response}"
      
      {
        messages: [{ role: 'assistant', content: response }],
        last_response: response
      }
    end

    node :handle_farewell do |state|
      response = "Goodbye! Have a great day!"
      puts "🤖 Bot: #{response}"
      
             LangGraphRB::Commands.update_and_goto(
         { 
           messages: [{ role: 'assistant', content: response }],
           last_response: response,
           should_end: true
         },
         LangGraphRB::Graph::FINISH
       )
    end

    node :handle_help do |state|
      response = "I can help with greetings, weather queries, or general conversation. Just ask!"
      puts "🤖 Bot: #{response}"
      
      {
        messages: [{ role: 'assistant', content: response }],
        last_response: response
      }
    end

    node :handle_weather do |state|
      response = "I'm sorry, I don't have access to real weather data yet, but it's probably nice outside!"
      puts "🤖 Bot: #{response}"
      
      {
        messages: [{ role: 'assistant', content: response }],
        last_response: response
      }
    end

    node :general_response do |state|
      responses = [
        "That's interesting! Tell me more.",
        "I see what you mean. Can you elaborate?",
        "Thanks for sharing that with me!",
        "That's a good point. What do you think about it?"
      ]
      
      response = responses.sample
      puts "🤖 Bot: #{response}"
      
      {
        messages: [{ role: 'assistant', content: response }],
        last_response: response
      }
    end

    # Define edges
    set_entry_point :receive_input
    edge :receive_input, :analyze_intent

    # Conditional routing based on intent
    conditional_edge :analyze_intent, ->(state) { state[:intent] }, {
      'greeting' => :handle_greeting,
      'farewell' => :handle_farewell,
      'help_request' => :handle_help,
      'weather_query' => :handle_weather,
      'general_chat' => :general_response
    }

    # All responses go back to waiting for input (except farewell)
    edge :handle_greeting, :receive_input
    edge :handle_help, :receive_input  
    edge :handle_weather, :receive_input
    edge :general_response, :receive_input
  end

  # Compile the graph
  graph.compile!
  
  # Show the graph structure
  puts "\n📊 Graph Structure (Mermaid):"
  puts graph.to_mermaid
  puts

  # Example conversations
  conversations = [
    "Hello there!",
    "What's the weather like?", 
    "Can you help me?",
    "That's cool, thanks!",
    "Goodbye!"
  ]

  conversations.each_with_index do |input, i|
    puts "\n--- Conversation #{i + 1} ---"
    
    result = graph.invoke({ input: input })
    
    puts "Final state keys: #{result.keys}"
    puts "Message count: #{result[:messages]&.length || 0}"
    puts "Step count: #{result[:step_count]}"
    
    # Break if bot indicated it should end
    break if result[:should_end]
  end
  
  puts "\n✅ Basic example completed!"
end

# Example with streaming execution
def streaming_example
  puts "\n=== Streaming Execution Example ==="
  
  graph = LangGraphRB::Graph.new do
    node :step1 do |state|
      puts "  🔄 Executing step 1..."
      sleep(0.5)  # Simulate work
      { step: 1, data: "Processed in step 1" }
    end

    node :step2 do |state|
      puts "  🔄 Executing step 2..."
      sleep(0.5)
      { step: 2, data: state[:data] + " -> Processed in step 2" }
    end

    node :step3 do |state|
      puts "  🔄 Executing step 3..."
      sleep(0.5)
      { step: 3, data: state[:data] + " -> Final processing" }
    end

    set_entry_point :step1
    edge :step1, :step2
    edge :step2, :step3
    set_finish_point :step3
  end

  graph.compile!

  # Stream the execution
  puts "📡 Streaming execution:"
  graph.stream({ input: "Hello streaming!" }) do |step_result|
    puts "  📊 Step #{step_result[:step]}: #{step_result[:active_nodes].inspect}"
    puts "     State: #{step_result[:state][:data]}" if step_result[:state][:data]
    puts "     Completed: #{step_result[:completed]}"
  end
  
  puts "✅ Streaming example completed!"
end

# Run examples
if __FILE__ == $0
  basic_example
  streaming_example
end 