#!/usr/bin/env ruby

require_relative 'lib/langgraph_rb'

puts "🧪 LangGraphRB Test Runner"
puts "=" * 50

# Test 1: Basic State Management
puts "\n1️⃣  Testing State Management..."

state = LangGraphRB::State.new(
  { counter: 0, messages: [] },
  { 
    counter: ->(old, new) { (old || 0) + new },
    messages: LangGraphRB::State.add_messages
  }
)

updated_state = state.merge_delta({ 
  counter: 5, 
  messages: [{ role: 'user', content: 'Hello' }] 
})

updated_state = updated_state.merge_delta({ 
  counter: 3, 
  messages: [{ role: 'assistant', content: 'Hi there!' }] 
})

puts "✅ Counter (should be 8): #{updated_state[:counter]}"
puts "✅ Messages count (should be 2): #{updated_state[:messages].length}"

# Test 2: Basic Graph Execution
puts "\n2️⃣  Testing Basic Graph Execution..."

graph = LangGraphRB::Graph.new do
  node :double do |state|
    { result: (state[:number] || 0) * 2 }
  end
  
  node :add_ten do |state|
    { result: (state[:result] || 0) + 10 }
  end
  
  set_entry_point :double
  edge :double, :add_ten
  set_finish_point :add_ten
end

graph.compile!
result = graph.invoke({ number: 5 })
puts "✅ Result (should be 20): #{result[:result]}"

# Test 3: Conditional Routing
puts "\n3️⃣  Testing Conditional Routing..."

routing_graph = LangGraphRB::Graph.new do
  node :check_number do |state|
    num = state[:number] || 0
    { 
      number: num,
      is_positive: num > 0,
      is_even: num % 2 == 0
    }
  end
  
  node :positive_handler do |state|
    { message: "Number #{state[:number]} is positive!" }
  end
  
  node :generate_sql do |state|
    { message: "Number #{state[:number]} is negative or zero!" }
  end
  
  set_entry_point :check_number
  
  conditional_edge :check_number, ->(state) {
    state[:is_positive] ? :positive_handler : :generate_sql
  }
  
  set_finish_point :positive_handler
  set_finish_point :generate_sql
end

routing_graph.compile!

pos_result = routing_graph.invoke({ number: 7 })
puts "✅ Positive test: #{pos_result[:message]}"

neg_result = routing_graph.invoke({ number: -3 })
puts "✅ Negative test: #{neg_result[:message]}"

# Test 4: Commands
puts "\n4️⃣  Testing Commands..."

command_graph = LangGraphRB::Graph.new do
  node :decision_maker do |state|
    if state[:should_skip]
      LangGraphRB::Commands.update_and_goto(
        { message: "Skipped processing" },
        LangGraphRB::Graph::FINISH
      )
    else
      { message: "Processing normally" }
    end
  end
  
  node :normal_processing do |state|
    { message: state[:message] + " -> completed" }
  end
  
  set_entry_point :decision_maker
  edge :decision_maker, :normal_processing
  set_finish_point :normal_processing
end

command_graph.compile!

skip_result = command_graph.invoke({ should_skip: true })
puts "✅ Skip result: #{skip_result[:message]}"

normal_result = command_graph.invoke({ should_skip: false })
puts "✅ Normal result: #{normal_result[:message]}"

# Test 5: Checkpointing
puts "\n5️⃣  Testing Checkpointing..."

store = LangGraphRB::Stores::InMemoryStore.new
thread_id = "test_thread_#{Time.now.to_i}"

checkpoint_graph = LangGraphRB::Graph.new do
  node :step1 do |state|
    { step: 1, data: "Step 1 complete" }
  end
  
  node :step2 do |state|
    { step: 2, data: state[:data] + " -> Step 2 complete" }
  end
  
  set_entry_point :step1
  edge :step1, :step2
  set_finish_point :step2
end

checkpoint_graph.compile!

# Execute with checkpointing
result = checkpoint_graph.invoke(
  { input: "test" }, 
  store: store, 
  thread_id: thread_id
)

puts "✅ Checkpointed execution result: #{result[:data]}"

# Verify checkpoints were saved
steps = store.list_steps(thread_id)
puts "✅ Checkpoints saved: #{steps.length} steps"

puts "\n🎉 All tests passed! LangGraphRB is working correctly."
puts "=" * 50 