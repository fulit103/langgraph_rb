#!/usr/bin/env ruby

require_relative '../lib/langgraph_rb'

# Very simple mock LLM client. Bring your own real client instead.
class MockLLMClient
  def call(messages)
    last_user_message = messages.reverse.find { |m| m[:role] == 'user' }&.dig(:content)
    "(mock) You said: #{last_user_message}"
  end
end

def llmnode_example
  puts "=== LLMNode Example ==="

  mock_llm = MockLLMClient.new

  # Build a minimal chat graph using an LLM node.
  graph = LangGraphRB::Graph.new(state_class: LangGraphRB::State) do
    # Collect user input into the message history
    node :receive_input do |state|
      user_msg = { role: 'user', content: state[:input].to_s }
      existing = state[:messages] || []
      { messages: existing + [user_msg], last_user_message: state[:input].to_s }
    end

    # LLM node – uses a custom block to call the provided client via context
    # Note: The default LLM behavior can be used once the core library wires a default callable.
    llm_node :chat, llm_client: mock_llm, system_prompt: "You are a helpful assistant." do |state, context|
      messages = state[:messages] || []

      puts "########################################################"
      puts "########################################################"

      puts "context: #{context}"

      puts "########################################################"
      puts "########################################################"

      # Optionally prepend a system prompt
      if context[:system_prompt]
        messages = [{ role: 'system', content: context[:system_prompt] }] + messages
      end

      response = context[:llm_client].call(messages)

      assistant_msg = { role: 'assistant', content: response }
      { messages: (state[:messages] || []) + [assistant_msg], last_response: response }
    end

    set_entry_point :receive_input
    edge :receive_input, :chat
    set_finish_point :chat
  end

  graph.compile!

  # Single-turn example
  result = graph.invoke({ messages: [], input: "Hello there!" })

  puts "Assistant: #{result[:last_response]}"
  puts "Messages:" 
  (result[:messages] || []).each { |m| puts "  - #{m[:role]}: #{m[:content]}" }

  # Multi-turn example (reuse message history)
  second = graph.invoke({ messages: result[:messages], input: "What's the weather like?" })

  puts "\nAssistant (turn 2): #{second[:last_response]}"
  puts "Messages (after 2 turns):"
  (second[:messages] || []).each { |m| puts "  - #{m[:role]}: #{m[:content]}" }
end

llmnode_example


