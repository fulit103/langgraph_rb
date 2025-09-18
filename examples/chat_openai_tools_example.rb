#!/usr/bin/env ruby
require_relative '../lib/langgraph_rb'

class MovieInfoTool < LangGraphRB::ToolBase
  define_function :search_movie, description: "MovieInfoTool: Search for a movie by title" do
    property :query, type: "string", description: "The movie title to search for", required: true
  end

  define_function :get_movie_details, description: "MovieInfoTool: Get detailed information about a specific movie" do
    property :movie_id, type: "integer", description: "The TMDb ID of the movie", required: true
  end

  def initialize(api_key: "demo")
    @api_key = api_key
  end

  def search_movie(query:)
    tool_response({ results: [ { id: 603, title: query, year: 1999 } ] })
  end

  def get_movie_details(movie_id:)
    tool_response({ id: movie_id, title: "The Matrix", overview: "A computer hacker learns the truth of reality." })
  end
end

def run_chat_openai_tools
  tools = MovieInfoTool.new(api_key: ENV['TMDB_API_KEY'] || 'demo')

  chat = LangGraphRB::ChatOpenAI.new(model: ENV.fetch('OPENAI_MODEL', 'gpt-4o-mini'), temperature: 0)
  chat = chat.bind_tools(tools)

  observers = [LangGraphRB::Observers::LoggerObserver.new(level: :debug)]

  graph = LangGraphRB::Graph.new do
    node :receive_input do |state|
      user_msg = { role: 'user', content: state[:input].to_s }
      existing = state[:messages] || []
      { messages: existing + [user_msg] }
    end

    llm_node :chat, llm_client: chat, system_prompt: "You are a movie assistant. Use tools when helpful." do |state, context|
      messages = state[:messages] || []
      messages = [{ role: 'system', content: context[:system_prompt] }] + messages if context[:system_prompt]

      puts "########################"
      puts "########################"
      puts "messages: #{messages}"
      puts "########################"
      puts "########################"

      response = context[:llm_client].call(messages)

      if response.is_a?(Hash) && response[:tool_calls]
        assistant_msg = { role: 'assistant', content: nil, tool_calls: response[:tool_calls] }
        { messages: (state[:messages] || []) + [assistant_msg], tool_call: response[:tool_calls].first }
      else
        assistant_msg = { role: 'assistant', content: response.to_s }
        { messages: (state[:messages] || []) + [assistant_msg], last_response: response.to_s }
      end
    end    

    node :tool do |state|
      puts "TOOL CALL #########################"
      tool_name = state[:tool_call][:name]
      tool_args = state[:tool_call][:arguments]

      puts "tool_name: #{tool_name}"
      puts "tool_args: #{tool_args}"

      puts "before tool call #########################"
      tool_result = tools.send(tool_name, query: tool_args[:query])

      puts "########################"
      puts "########################"
      puts "tool_name: #{tool_name}"
      puts "tool_args: #{tool_args}"
      puts "tool_result: #{tool_result}"
      puts "########################"
      puts "########################"

      { messages: (state[:messages] || []) + [{ role: 'tool', content: tool_result.to_json, tool_calls: [] }] }
    end    

    node :final_answer do |state|
      puts "TOOL RESULT #########################"
      puts "last response: #{state[:last_response]}"
      puts "########################"
      puts "########################"
      { **state }
    end

    set_entry_point :receive_input
    edge :receive_input, :chat

    conditional_edge :chat, ->(state) {    
      state[:tool_call] ? "use_tool" : "final_answer"
    }, {
      "use_tool" => :tool,
      "final_answer" => :final_answer
    }

    edge :tool, :chat
    set_finish_point :final_answer
  end

  graph.compile!

  start = { messages: [], input: "Find details about 'The Matrix'" }
  result = graph.invoke(start, observers: observers)
  puts "Messages:"
  (result[:messages] || []).each do |m|
    if m[:role] == 'assistant' && m[:tool_calls]
      names = m[:tool_calls].map { |tc| tc[:name] }.join(', ')
      puts "- assistant tool_calls: #{names}"
    else
      puts "- #{m[:role]}: #{m[:content]}"
    end
  end

  puts "\nFull result:"
  puts result
end

run_chat_openai_tools


