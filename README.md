# LangGraphRB 🔄

A Ruby library for building stateful, multi-actor applications with directed graphs, inspired by [LangGraph](https://langchain-ai.github.io/langgraph/).

## Overview

LangGraphRB models complex workflows as directed graphs where:
- **Nodes** are executable functions that process state and return updates
- **Edges** define the flow between nodes with support for conditional routing
- **State** is a centralized, typed object that flows through the entire execution
- **Commands** control execution flow with operations like `goto`, `send`, and `interrupt`

## Key Features

- 🔄 **Graph-based Orchestration**: Model complex workflows as directed graphs
- 🏃 **Parallel Execution**: Execute multiple nodes simultaneously with thread-safe state management
- 💾 **Checkpointing**: Automatic state persistence and resumption support
- 🤖 **Human-in-the-Loop**: Built-in support for human intervention and approval workflows
- 🔀 **Map-Reduce Operations**: Fan-out to parallel processing and collect results
- 📊 **Visualization**: Generate Mermaid diagrams of your graphs
- 🎯 **Type-Safe State**: Centralized state with customizable reducers
- ⚡ **Streaming Execution**: Real-time progress monitoring

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'langgraph_rb'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install langgraph_rb
```

## Quick Start

Here's a simple example of building a chatbot with conditional routing:

```ruby
require 'langgraph_rb'

# Create a graph with a DSL
graph = LangGraphRB::Graph.new do
  # Define nodes
  node :greet do |state|
    { message: "Hello! How can I help you?" }
  end

  node :analyze_intent do |state|
    user_input = state[:user_input].to_s.downcase
    intent = user_input.include?('weather') ? 'weather' : 'general'
    { intent: intent }
  end

  node :weather_response do |state|
    { message: "The weather is sunny today!" }
  end

  node :general_response do |state|
    { message: "That's interesting! Tell me more." }
  end

  # Define the flow
  set_entry_point :greet
  edge :greet, :analyze_intent

  # Conditional routing based on intent
  conditional_edge :analyze_intent, ->(state) { state[:intent] }, {
    'weather' => :weather_response,
    'general' => :general_response
  }

  # Both responses end the conversation
  set_finish_point :weather_response
  set_finish_point :general_response
end

# Compile and execute
graph.compile!
result = graph.invoke({ user_input: "How's the weather?" })
puts result[:message]  # => "The weather is sunny today!"
```

## Core Concepts

### State Management

State is centralized and flows through the entire graph. You can define reducers for specific keys to control how state updates are merged:

```ruby
# State with custom reducers
state = LangGraphRB::State.new(
  { messages: [], count: 0 },
  { 
    messages: LangGraphRB::State.add_messages,  # Append to array
    count: ->(old, new) { (old || 0) + new }    # Sum values
  }
)
```

### Nodes

Nodes are the executable units of your graph. They receive the current state and return updates:

```ruby
# Simple node
node :process_data do |state|
  processed = state[:data].map(&:upcase)
  { processed_data: processed, processing_complete: true }
end

# Node with context
node :call_api do |state, context|
  api_client = context[:api_client]
  result = api_client.call(state[:query])
  { api_result: result }
end
```

### Edges and Routing

Define how execution flows between nodes:

```ruby
# Simple edge
edge :node_a, :node_b

# Conditional edge with router function
conditional_edge :decision_node, ->(state) { 
  state[:condition] ? :path_a : :path_b 
}

# Fan-out to multiple nodes
fan_out_edge :distributor, [:worker_1, :worker_2, :worker_3]
```

### Commands

Control execution flow with commands:

```ruby
node :decision_node do |state|
  if state[:should_continue]
    LangGraphRB::Commands.update_and_goto(
      { status: 'continuing' }, 
      :next_node
    )
  else
    LangGraphRB::Commands.end_execution({ status: 'stopped' })
  end
end
```

### Parallel Processing with Send

Use `Send` commands for map-reduce operations:

```ruby
node :fan_out do |state|
  tasks = state[:tasks]
  
  # Send each task to parallel processing
  sends = tasks.map do |task|
    LangGraphRB::Send.new(to: :process_task, payload: { task: task })
  end
  
  LangGraphRB::MultiSend.new(sends)
end
```

## Advanced Features

### Checkpointing and Resumption

Persist execution state and resume from any point:

```ruby
# Use a persistent store
store = LangGraphRB::Stores::FileStore.new('./checkpoints')
thread_id = 'my_workflow_123'

# Execute with checkpointing
result = graph.invoke(
  { input: 'data' }, 
  store: store, 
  thread_id: thread_id
)

# Resume later
resumed_result = graph.resume(
  thread_id, 
  { additional_input: 'more_data' }, 
  store: store
)
```

### Human-in-the-Loop

Pause execution for human input:

```ruby
node :request_approval do |state|
  LangGraphRB::Commands.interrupt(
    message: "Please review and approve this action",
    data: { action: state[:proposed_action] }
  )
end

# Set up interrupt handler
runner = LangGraphRB::Runner.new(graph, store: store, thread_id: thread_id)
runner.on_interrupt do |interrupt|
  puts interrupt.message
  # Get user input (this would be from a UI in practice)
  user_response = gets.chomp
  { approval: user_response == 'approve' }
end
```

### Streaming Execution

Monitor execution progress in real-time:

```ruby
graph.stream({ input: 'data' }) do |step_result|
  puts "Step #{step_result[:step]}: #{step_result[:active_nodes]}"
  puts "State keys: #{step_result[:state].keys}"
  puts "Completed: #{step_result[:completed]}"
end
```

### Visualization

Generate Mermaid diagrams of your graphs:

```ruby
graph.compile!
puts graph.to_mermaid

# Output:
# graph TD
#     start((START))
#     node_a["node_a"]
#     node_b["node_b"]
#     __end__((END))
#     start --> node_a
#     node_a --> node_b
#     node_b --> __end__
```

## Storage Options

Choose from different storage backends:

```ruby
# In-memory (default, not persistent)
store = LangGraphRB::Stores::InMemoryStore.new

# File-based with YAML
store = LangGraphRB::Stores::FileStore.new('./data/checkpoints')

# File-based with JSON
store = LangGraphRB::Stores::JsonStore.new('./data/checkpoints')
```

## Specialized Nodes

### LLM Nodes

For LLM integration (bring your own client):

```ruby
llm_node :chat, llm_client: my_llm_client, system_prompt: "You are a helpful assistant"

# Or with custom logic
llm_node :custom_chat, llm_client: my_llm_client do |state, context|
  messages = prepare_messages(state[:conversation])
  response = context[:llm_client].call(messages)
  { messages: [{ role: 'assistant', content: response }] }
end
```

### Tool Nodes

For tool/function calls:

```ruby
tool_node :search, tool: SearchTool.new

# The tool should respond to #call
class SearchTool
  def call(args)
    # Perform search and return results
    search_api.query(args[:query])
  end
end
```

## Examples

Check out the `examples/` directory for complete working examples:

- `basic_example.rb` - Simple chatbot with conditional routing
- `advanced_example.rb` - Research assistant with parallel processing and human-in-the-loop

Run them with:

```bash
$ ruby examples/basic_example.rb
$ ruby examples/advanced_example.rb
```

## Comparison with LangGraph (Python)

| Feature | LangGraphRB | LangGraph |
|---------|-------------|-----------|
| Graph Definition | ✅ DSL + Builder | ✅ Builder Pattern |
| Parallel Execution | ✅ Thread-based | ✅ AsyncIO |
| Checkpointing | ✅ Multiple stores | ✅ Multiple stores |
| Human-in-the-loop | ✅ Interrupt system | ✅ Interrupt system |
| Map-Reduce | ✅ Send commands | ✅ Send API |
| Streaming | ✅ Block-based | ✅ AsyncIO streams |
| Visualization | ✅ Mermaid | ✅ Mermaid |
| State Management | ✅ Reducers | ✅ Reducers |

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yourusername/langgraph_rb.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Roadmap

- [ ] Redis-based checkpointing store  
- [ ] Built-in LLM client integrations
- [ ] Web UI for monitoring executions
- [ ] Performance optimizations
- [ ] More comprehensive test suite
- [ ] Integration with Sidekiq for background processing
- [x] Metrics and observability features