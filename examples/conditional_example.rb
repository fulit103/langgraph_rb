#!/usr/bin/env ruby

require_relative '../lib/langgraph_rb'

graph = LangGraphRB::Graph.new do
    node :greeting do |state|
        { message: "Hello, how can I help you today?" }
    end

    node :analyze_intent do |state|
        { intent: state[:message].downcase.include?("weather") ? "weather" : "general" }
    end
    
    conditional_edge :analyze_intent, ->(state) { state[:intent] }, {
        "weather" => :weather_response,
        "general" => :general_response
    }

    node :weather_response do |state|
        { message: "The weather is sunny today!" }
    end

    node :general_response do |state|
        { message: "That's interesting! Tell me more." }
    end

    set_entry_point :greeting
    edge :greeting, :analyze_intent
    set_finish_point :weather_response
    set_finish_point :general_response
end
    

graph.compile!
puts graph.to_mermaid
result = graph.invoke({ message: "How's the weather?" })
puts result[:message]  # => "The weather is sunny today!"

