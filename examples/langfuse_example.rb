#!/usr/bin/env ruby
require 'langfuse'
require_relative '../lib/langgraph_rb'

url = 'https://us.cloud.langfuse.com'

Langfuse.configure do |config|
    config.public_key = ENV['LANGFUSE_PUBLIC_KEY']  # e.g., 'pk-lf-...'
    config.secret_key = ENV['LANGFUSE_SECRET_KEY']  # e.g., 'sk-lf-...'
    config.host = url
    config.debug = true # Enable debug logging
end


class LangfuseObserver < LangGraphRB::Observers::BaseObserver

    def on_graph_start(event)
        @trace ||= Langfuse.trace(
            name: "graph-start2",
            thread_id: event.thread_id,
            metadata: event.to_h
        )
    end

    def on_node_end(event)
        span = Langfuse.span(
            name: "node-#{event.node_name}",
            trace_id: @trace.id,
            input: event.to_h,            
        )
        Langfuse.update_span(span)        
    end
end


def langfuse_example
  puts "########################################################"
  puts "########################################################"
  puts "########################################################"
  puts "=== Langfuse Example ==="
  
  # Create a simple graph for demonstration

  graph = LangGraphRB::Graph.new(state_class: LangGraphRB::State) do
    node :process_message do |state|
        sleep(Random.rand(0.1..0.5))
      { message: "Processed: #{state[:message]}" }
    end
    
    conditional_edge :process_message, -> (state) { 
        sleep(Random.rand(0.1..0.5))
      if state[:value] > 0 and state[:value] < 10
        puts "Processed between 0 and 10"
        return :process_between_0_and_10
      elsif state[:value] > 10
        puts "Processed greater than 10"
        return :process_greater_than_10
      else
        puts "Processed less than 0"
        return :process_less_than_0
      end
    }

    node :process_between_0_and_10 do |state|
      { message: "Processed between 0 and 10: #{state[:message]}" }      
    end

    node :process_greater_than_10 do |state|
      { message: "Processed greater than 10: #{state[:message]}" }
    end

    node :process_less_than_0 do |state|
      { message: "Processed less than 0: #{state[:message]}" }
    end

    set_entry_point :process_message    
    set_finish_point :process_between_0_and_10
    set_finish_point :process_greater_than_10
    set_finish_point :process_less_than_0
  end

  
  
  graph.compile!
  result = graph.invoke({ message: "Hello World", value:  31}, observers: [LangfuseObserver.new])
  puts "Result: #{result}"
  puts "########################################################"
  puts "########################################################"
  puts "########################################################"
  puts "########################################################"
end

langfuse_example

