#!/usr/bin/env ruby
require 'langfuse'
require_relative '../lib/langgraph_rb'

url = 'https://us.cloud.langfuse.com'

puts "LANGFUSE_PUBLIC_KEY: #{ENV['LANGFUSE_PUBLIC_KEY']}"
puts "LANGFUSE_SECRET_KEY: #{ENV['LANGFUSE_SECRET_KEY']}"
puts "LANGFUSE_HOST: #{url}"
puts "LANGFUSE_DEBUG: #{true}"

Langfuse.configure do |config|
    config.public_key = ENV['LANGFUSE_PUBLIC_KEY']  # e.g., 'pk-lf-...'
    config.secret_key = ENV['LANGFUSE_SECRET_KEY']  # e.g., 'sk-lf-...'
    config.host = url
    config.debug = true # Enable debug logging
end

# Very simple mock LLM client. Bring your own real client instead.
class MockLLMClient

    def set_observers(observers, node_name)
        @observers = observers
        @node_name = node_name
    end

    def call(messages)

        data = {
            name: "MockLLMClient",
            model: "MockLLM",
            model_parameters: {
                temperature: 0.5,
                max_tokens: 1000
            },
            input: messages,
        }

        log_llm_request(data)

        last_user_message = messages.reverse.find { |m| m[:role] == 'user' }&.dig(:content)
        "(mock) You said: #{last_user_message}"

        data = {
            output: "(mock) You said: #{last_user_message}",
            prompt_tokens: 100,
            completion_tokens: 100,
            total_tokens: 200,
        }

        log_llm_response(data)
    end

    def log_llm_request(data)
        @observers&.each do |observer|
            observer.on_llm_request(data, @node_name)
        end
    end
  
    def log_llm_response(data)
        @observers&.each do |observer|
            observer.on_llm_response(data, @node_name)
        end
    end
end

class LangfuseObserver < LangGraphRB::Observers::BaseObserver

    def initialize
        @trace = nil
        @spans_by_node = {}
    end

    def on_graph_start(event)
        @trace ||= Langfuse.trace(
            name: "llm-graph",
            thread_id: event.thread_id,            
            metadata: event.to_h
        )
    end

    def on_node_start(event)
        @spans_by_node[event.node_name] ||= {
            span: Langfuse.span(
                name: "node-#{event.node_name}",
                trace_id: @trace.id,
                input: event.to_h,            
            ),
            generation: nil
        }
        Langfuse.update_span(@spans_by_node[event.node_name][:span])        
    end

    def on_node_end(event)
        # @spans_by_node[event.node_name] ||= {
        #     span: Langfuse.span(
        #         name: "node-#{event.node_name}",
        #         trace_id: @trace.id,
        #         input: event.to_h,            
        #     ),
        #     generation: nil
        # }
        # Langfuse.update_span(@spans_by_node[event.node_name][:span])        
    end

    def on_llm_request(event, node_name)
        puts "########################################################"
        puts "on_llm_request: #{event}"
        puts "node_name: #{node_name}"
        puts "spans_by_node: #{@spans_by_node}"
        puts "$$$$--------------------------------------------------------$$$$"
        span = @spans_by_node[node_name][:span]
        generation = Langfuse.generation(
            name: event[:name],
            trace_id: @trace.id,
            parent_observation_id: span.id,
            model: event[:model],
            model_parameters: event[:model_parameters],
            input: event[:input]
        )

        @spans_by_node[node_name.to_sym][:generation] = generation        
    end

    def on_llm_response(event, node_name)
        puts "########################################################"
        puts "on_llm_response: #{event}"
        puts "node_name: #{node_name}"
        puts "spans_by_node: #{@spans_by_node}"
        puts "$$$$--------------------------------------------------------$$$$"

        generation = @spans_by_node[node_name][:generation]

        return if generation.nil?

        generation.output = event[:output]
        generation.usage = Langfuse::Models::Usage.new(
            prompt_tokens: event[:prompt_tokens],
            completion_tokens: event[:completion_tokens], 
            total_tokens: event[:total_tokens]
        )
        Langfuse.update_generation(generation)

        @spans_by_node[node_name.to_sym][:generation] = nil
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
  result = graph.invoke({ messages: [], input: "Hello there!" }, observers: [LangfuseObserver.new])

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


