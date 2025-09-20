#!/usr/bin/env ruby

require_relative '../lib/langgraph_rb'

# Mock LLM client that can incorporate tool outputs when present
class MockLLMClient
  def call(messages)
    last_user = messages&.reverse&.find { |m| m[:role] == 'user' }&.dig(:content)
    last_tool = messages&.reverse&.find { |m| m[:role] == 'tool' }&.dig(:content)

    if last_tool
      "(mock) Based on tool result: #{last_tool} | Answering user: #{last_user}"
    else
      "(mock) You said: #{last_user}"
    end
  end
end

# Simple search tool that returns a faux result string
class SearchTool
  def self.call(args)
    query = args.is_a?(Hash) ? args[:query] || args['query'] : args
    query ||= args.to_s
    "Results for '#{query}': [Result A, Result B, Result C]"
  end
end

def tool_and_llm_example
  puts "=== Tool + LLM Example ==="

  mock_llm = MockLLMClient.new

  graph = LangGraphRB::Graph.new(state_class: LangGraphRB::State) do
    # 1) Capture user input into the message history
    node :receive_input do |state|
      user_msg = { role: 'user', content: state[:input].to_s }
      existing = state[:messages] || []
      { messages: existing + [user_msg], last_user_message: state[:input].to_s }
    end

    # 2) Decide whether to call a tool based on the user's request
    # If the user says: "search <query>", produce a tool_call for SearchTool
    llm_node :router, llm_client: mock_llm, system_prompt: "You are a helpful assistant that can decide to call tools when asked." do |state, context|
      last_user = state[:last_user_message].to_s

      if (match = last_user.match(/^\s*search\s+(.+)$/i))
        query = match[1].strip
        tool_call = {
          id: "call_#{Time.now.to_i}",
          name: 'search',
          args: { query: query }
        }

        assistant_msg = {
          role: 'assistant',
          content: "Let me search for: #{query}",
          tool_calls: [tool_call]
        }

        {
          messages: (state[:messages] || []) + [assistant_msg],
          tool_call: tool_call # also put it in state for convenience
        }
      else
        # No tool needed; provide a direct assistant response using the LLM
        messages = state[:messages] || []
        messages = [{ role: 'system', content: context[:system_prompt] }] + messages if context[:system_prompt]
        response = context[:llm_client].call(messages)

        {
          messages: (state[:messages] || []) + [{ role: 'assistant', content: response }],
          last_response: response
        }
      end
    end

    # 3) Execute the tool if requested and append a tool message
    # Use a custom block to merge the tool message with existing history
    tool_node :use_tool, tool: SearchTool do |state|
      # Determine the tool call (from state or messages)
      tool_call = state[:tool_call]
      unless tool_call
        # Fallback: look for a message containing tool_calls
        (state[:messages] || []).reverse.each do |msg|
          if msg[:tool_calls] && msg[:tool_calls].first
            tool_call = msg[:tool_calls].first
            break
          end
        end
      end

      return { error: 'No tool call found' } unless tool_call

      result = SearchTool.call(tool_call[:args])

      tool_msg = {
        role: 'tool',
        content: result.to_s,
        tool_call_id: tool_call[:id]
      }

      {
        messages: (state[:messages] || []) + [tool_msg],
        tool_result: result
      }
    end

    # 4) Produce the final answer with the LLM, using any tool results
    llm_node :final_answer, llm_client: mock_llm, system_prompt: "Use tool results if available to answer the user."

    # Flow
    set_entry_point :receive_input
    edge :receive_input, :router

    # If there is a tool_call, go to :use_tool, otherwise go directly to :final_answer
    conditional_edge :router, ->(state) {
      state[:tool_call] ? "use_tool" : "final_answer"
    }, {
      "use_tool" => :use_tool,
      "final_answer" => :final_answer
    }

    edge :use_tool, :router
    set_finish_point :final_answer
  end

  graph.compile!

  puts graph.to_mermaid

  puts "\n— Example 1: No tool needed —"
  result1 = graph.invoke({ messages: [], input: "Tell me a joke." })
  puts "Assistant: #{result1[:last_response]}"

  puts "\n— Example 2: Tool is used —"
  result2 = graph.invoke({ messages: [], input: "search Ruby LangGraphRB" })
  final_message = (result2[:messages] || []).reverse.find { |m| m[:role] == 'assistant' }&.dig(:content)
  puts "Assistant: #{final_message}"
  tool_message = (result2[:messages] || []).reverse.find { |m| m[:role] == 'tool' }&.dig(:content)
  puts "(Tool) #{tool_message}"
end

tool_and_llm_example 


