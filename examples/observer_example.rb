#!/usr/bin/env ruby

require_relative '../lib/langgraph_rb'
require 'logger'

# Custom observer for metrics collection
class MetricsObserver < LangGraphRB::Observers::BaseObserver
  def initialize(metrics_client)
    @metrics = metrics_client
  end

  def on_node_end(event)
    @metrics.histogram('node.duration', event.duration * 1000, {
      node_name: event.node_name.to_s,
      node_type: event.node_class&.name
    })
  end

  def on_node_error(event)
    @metrics.increment('node.error', {
      node_name: event.node_name.to_s,
      error_type: event.error&.class&.name
    })
  end
end

# Database observer for audit trails
class DatabaseObserver < LangGraphRB::Observers::BaseObserver
  def initialize(db_connection)
    @db = db_connection
  end

  def on_graph_start(event)
    @db.execute(
      "INSERT INTO graph_executions (thread_id, graph_class, started_at) VALUES (?, ?, ?)",
      event.thread_id, event.graph.class.name, event.timestamp
    )
  end

  def on_node_end(event)
    @db.execute(
      "INSERT INTO node_executions (thread_id, step_number, node_name, duration_ms, completed_at) VALUES (?, ?, ?, ?, ?)",
      event.thread_id, event.step_number, event.node_name.to_s, (event.duration * 1000).round(2), event.timestamp
    )
  end
end

class MyMetricsClient
  def histogram(name, value, tags)
    puts "Histogram: #{name}, #{value}, #{tags}"
  end

  def increment(name, tags)
    puts "Increment: #{name}, #{tags}"
  end
end

class MyDBConnection
  def execute(query, *args)
    puts "Executing: #{query}, #{args}"
  end
end

def observer_example
  puts "=== Observer Example ==="
  
  # Create a simple graph for demonstration
  initial_state = LangGraphRB::State.new(
    { message: "", messages: [], response: "" }
  )

  # Create the graph using DSL
  graph = LangGraphRB::Graph.new(state_class: LangGraphRB::State) do
    # Simple node that processes messages
    node :process_message do |state|
      puts "Processing: #{state[:message]}"
      {
        messages: state[:messages] + [state[:message]],
        response: "Processed: #{state[:message]}"
      }
    end

    # Set up the flow
    set_entry_point :process_message
    set_finish_point :process_message
  end

  # Compile the graph
  graph.compile!

  # Basic logging observability
  logger_observer = LangGraphRB::Observers::LoggerObserver.new(
    logger: Logger.new('graph_execution.log'),
    level: :info
  )

  puts "\n--- Running with basic logging observer ---"
  graph.invoke(
    { message: "Hello World", messages: [], response: "" },
    observers: [logger_observer]
  )

  my_metrics_client = MyMetricsClient.new
  my_db_connection = MyDBConnection.new

  # Use multiple observers
  puts "\n--- Running with multiple observers ---"
  graph.invoke(
    { message: "Testing multiple observers", messages: [], response: "" },
    observers: [
      logger_observer,
      MetricsObserver.new(my_metrics_client),
      DatabaseObserver.new(my_db_connection)
    ]
  )
  
  puts "\nObserver example completed! Check 'graph_execution.log' for logged events."
end

# Run the example
observer_example if __FILE__ == $0