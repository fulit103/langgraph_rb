#!/usr/bin/env ruby

require_relative '../lib/langgraph_rb'

# Custom state class for workflow example
class UserSetupState < LangGraphRB::State
  def initialize(schema = {}, reducers = nil)
    # If reducers are not provided, use our default reducers
    reducers ||= { user_info: LangGraphRB::State.merge_hash }
    super(schema, reducers)
  end
end

# Example 1: WITHOUT Reducers - Simple Replacement Behavior
def without_reducers_example
  puts "\n" + "=" * 60
  puts "🔴 EXAMPLE 1: WITHOUT REDUCERS (Simple Replacement)"
  puts "=" * 60
  
  # Create state without any reducers - everything is simple replacement
  state = LangGraphRB::State.new({ 
    counter: 0, 
    messages: [], 
    user_data: { name: "Alice" }
  })
  
  puts "Initial state:"
  puts "  Counter: #{state[:counter]}"
  puts "  Messages: #{state[:messages]}"
  puts "  User data: #{state[:user_data]}"
  
  # First update - this will REPLACE the values completely
  puts "\n📝 First update: { counter: 5, messages: ['Hello'], user_data: { age: 25 } }"
  state = state.merge_delta({ 
    counter: 5, 
    messages: ['Hello'], 
    user_data: { age: 25 }
  })
  
  puts "After first update:"
  puts "  Counter: #{state[:counter]} ← REPLACED with 5"
  puts "  Messages: #{state[:messages]} ← REPLACED with ['Hello']"
  puts "  User data: #{state[:user_data]} ← REPLACED with { age: 25 } (name is LOST!)"
  
  # Second update - again, simple replacement
  puts "\n📝 Second update: { counter: 3, messages: ['World'], user_data: { city: 'NYC' } }"
  state = state.merge_delta({ 
    counter: 3, 
    messages: ['World'], 
    user_data: { city: 'NYC' }
  })
  
  puts "After second update:"
  puts "  Counter: #{state[:counter]} ← REPLACED with 3 (lost the 5!)"
  puts "  Messages: #{state[:messages]} ← REPLACED with ['World'] (lost 'Hello'!)"
  puts "  User data: #{state[:user_data]} ← REPLACED with { city: 'NYC' } (lost age!)"
  
  puts "\n❌ PROBLEM: Without reducers, we lose previous data on every update!"
end

# Example 2: WITH Reducers - Intelligent Merging
def with_reducers_example
  puts "\n" + "=" * 60
  puts "🟢 EXAMPLE 2: WITH REDUCERS (Intelligent Merging)"
  puts "=" * 60
  
  # Create state WITH reducers that define how to combine values
  state = LangGraphRB::State.new(
    { 
      counter: 0, 
      messages: [], 
      user_data: { name: "Alice" }
    },
    { 
      counter: ->(old, new) { (old || 0) + new },           # ADD numbers
      messages: LangGraphRB::State.add_messages,             # APPEND to array
      user_data: LangGraphRB::State.merge_hash               # MERGE hashes
    }
  )
  
  puts "Initial state:"
  puts "  Counter: #{state[:counter]}"
  puts "  Messages: #{state[:messages]}"
  puts "  User data: #{state[:user_data]}"
  
  # First update - reducers will intelligently combine values
  puts "\n📝 First update: { counter: 5, messages: ['Hello'], user_data: { age: 25 } }"
  state = state.merge_delta({ 
    counter: 5, 
    messages: ['Hello'], 
    user_data: { age: 25 }
  })
  
  puts "After first update:"
  puts "  Counter: #{state[:counter]} ← ADDED: 0 + 5 = 5"
  puts "  Messages: #{state[:messages]} ← APPENDED: [] + ['Hello'] = ['Hello']"
  puts "  User data: #{state[:user_data]} ← MERGED: {name: 'Alice'} + {age: 25}"
  
  # Second update - reducers continue to combine intelligently
  puts "\n📝 Second update: { counter: 3, messages: ['World'], user_data: { city: 'NYC' } }"
  state = state.merge_delta({ 
    counter: 3, 
    messages: ['World'], 
    user_data: { city: 'NYC' }
  })
  
  puts "After second update:"
  puts "  Counter: #{state[:counter]} ← ADDED: 5 + 3 = 8"
  puts "  Messages: #{state[:messages]} ← APPENDED: ['Hello'] + ['World']"
  puts "  User data: #{state[:user_data]} ← MERGED: keeps all previous data!"
  
  puts "\n✅ SUCCESS: With reducers, we intelligently combine data instead of losing it!"
end

# Example 3: Built-in Reducers Demonstration
def builtin_reducers_example
  puts "\n" + "=" * 60
  puts "🛠️  EXAMPLE 3: BUILT-IN REDUCERS"
  puts "=" * 60
  
  # Demonstrate each built-in reducer
  puts "📌 1. add_messages - For building conversation history"
  messages_state = LangGraphRB::State.new(
    { messages: [] },
    { messages: LangGraphRB::State.add_messages }
  )
  
  messages_state = messages_state.merge_delta({ messages: { role: 'user', content: 'Hi!' } })
  messages_state = messages_state.merge_delta({ messages: [{ role: 'assistant', content: 'Hello!' }] })
  messages_state = messages_state.merge_delta({ messages: { role: 'user', content: 'How are you?' } })
  
  puts "Messages history: #{messages_state[:messages]}"
  
  puts "\n📌 2. append_string - For building text content"
  text_state = LangGraphRB::State.new(
    { story: "" },
    { story: LangGraphRB::State.append_string }
  )
  
  text_state = text_state.merge_delta({ story: "Once upon a time, " })
  text_state = text_state.merge_delta({ story: "there was a brave knight " })
  text_state = text_state.merge_delta({ story: "who saved the kingdom." })
  
  puts "Story: \"#{text_state[:story]}\""
  
  puts "\n📌 3. merge_hash - For building complex objects"
  profile_state = LangGraphRB::State.new(
    { profile: {} },
    { profile: LangGraphRB::State.merge_hash }
  )
  
  profile_state = profile_state.merge_delta({ profile: { name: "Bob" } })
  profile_state = profile_state.merge_delta({ profile: { age: 30, city: "Boston" } })
  profile_state = profile_state.merge_delta({ profile: { job: "Developer", age: 31 } }) # age updated
  
  puts "Profile: #{profile_state[:profile]}"
end

# Example 4: Custom Reducers
def custom_reducers_example
  puts "\n" + "=" * 60
  puts "⚙️  EXAMPLE 4: CUSTOM REDUCERS"
  puts "=" * 60
  
  # Custom reducer: Keep maximum value
  max_reducer = ->(old, new) { [old || 0, new || 0].max }
  
  # Custom reducer: Keep unique items in array
  unique_array_reducer = ->(old, new) do
    old_array = old || []
    new_items = new.is_a?(Array) ? new : [new]
    (old_array + new_items).uniq
  end
  
  # Custom reducer: Track changes with timestamps
  history_reducer = ->(old, new) do
    old_history = old || []
    timestamp = Time.now.strftime("%H:%M:%S")
    old_history + [{ value: new, timestamp: timestamp }]
  end
  
  state = LangGraphRB::State.new(
    { 
      max_score: 0, 
      unique_tags: [], 
      value_history: []
    },
    {
      max_score: max_reducer,
      unique_tags: unique_array_reducer,
      value_history: history_reducer
    }
  )
  
  puts "📊 Testing custom reducers..."
  
  # Test updates
  state = state.merge_delta({ max_score: 85, unique_tags: ['ruby', 'programming'], value_history: 'first' })
  puts "After update 1:"
  puts "  Max score: #{state[:max_score]}"
  puts "  Unique tags: #{state[:unique_tags]}"
  puts "  History: #{state[:value_history]}"
  
  sleep(1) # Small delay to show different timestamps
  
  state = state.merge_delta({ max_score: 72, unique_tags: ['ruby', 'web', 'api'], value_history: 'second' })
  puts "\nAfter update 2:"
  puts "  Max score: #{state[:max_score]} ← Kept the higher value (85)"
  puts "  Unique tags: #{state[:unique_tags]} ← Added new unique tags"
  puts "  History: #{state[:value_history]} ← Tracked all changes with timestamps"
  
  sleep(1)
  
  state = state.merge_delta({ max_score: 95, unique_tags: ['programming'], value_history: 'third' })
  puts "\nAfter update 3:"
  puts "  Max score: #{state[:max_score]} ← New maximum!"
  puts "  Unique tags: #{state[:unique_tags]} ← No duplicates added"
  puts "  History: #{state[:value_history]} ← Complete change history"
end

# Example 5: Real-world Graph Workflow Comparison
def workflow_comparison_example
  puts "\n" + "=" * 60
  puts "🚀 EXAMPLE 5: REAL-WORLD WORKFLOW COMPARISON"
  puts "=" * 60
  
  puts "🔴 WITHOUT Reducers - Data Loss Problem:"
  
  # Workflow without reducers
  graph_without = LangGraphRB::Graph.new do
    node :collect_user_info do |state|
      { user_info: { name: state[:name] } }
    end
    
    node :collect_preferences do |state|
      { user_info: { theme: state[:theme] } } # This OVERWRITES name!
    end
    
    node :finalize do |state|
      { result: "User setup complete: #{state[:user_info]}" }
    end
    
    set_entry_point :collect_user_info
    edge :collect_user_info, :collect_preferences
    edge :collect_preferences, :finalize
    set_finish_point :finalize
  end
  
  graph_without.compile!
  result_without = graph_without.invoke({ name: "Alice", theme: "dark" })
  puts "❌ Result: #{result_without[:result]} ← Lost the name!"
  
  puts "\n🟢 WITH Reducers - Data Preservation:"
  
  # Workflow with reducers
  graph_with = LangGraphRB::Graph.new(state_class: UserSetupState) do
    node :collect_user_info do |state|
      { user_info: { name: state[:name] } }
    end
    
    node :collect_preferences do |state|
      { user_info: { theme: state[:theme] } } # This MERGES with name!
    end
    
    node :finalize do |state|
      { result: "User setup complete: #{state[:user_info]}" }
    end
    
    set_entry_point :collect_user_info
    edge :collect_user_info, :collect_preferences
    edge :collect_preferences, :finalize
    set_finish_point :finalize
  end
  
  graph_with.compile!
  result_with = graph_with.invoke({ name: "Alice", theme: "dark" })
  puts "✅ Result: #{result_with[:result]} ← Preserved all data!"
end

# Example 6: Performance and Memory Considerations
def performance_example
  puts "\n" + "=" * 60
  puts "⚡ EXAMPLE 6: PERFORMANCE CONSIDERATIONS"
  puts "=" * 60
  
  puts "🔍 Memory efficiency with reducers:"
  
  # Show how reducers create new state objects (immutable)
  original_state = LangGraphRB::State.new(
    { data: [1, 2, 3] },
    { data: LangGraphRB::State.add_messages }
  )
  
  puts "Original state object_id: #{original_state.object_id}"
  puts "Original data object_id: #{original_state[:data].object_id}"
  
  new_state = original_state.merge_delta({ data: [4, 5] })
  
  puts "New state object_id: #{new_state.object_id} ← Different object (immutable)"
  puts "New data object_id: #{new_state[:data].object_id} ← New array object"
  puts "Original data unchanged: #{original_state[:data]} ← Still [1, 2, 3]"
  puts "New data: #{new_state[:data]} ← Combined result [1, 2, 3, 4, 5]"
  
  puts "\n💡 Key Benefits:"
  puts "  • Immutable updates (thread-safe)"
  puts "  • Predictable state changes"
  puts "  • Easy to debug and test"
  puts "  • Prevents accidental data loss"
end

# Run all examples
def run_all_examples
  puts "🧪 LangGraphRB State Reducers - Complete Tutorial"
  puts "=" * 80
  
  without_reducers_example
  with_reducers_example
  builtin_reducers_example
  custom_reducers_example
  workflow_comparison_example
  performance_example
  
  puts "\n" + "=" * 80
  puts "🎯 KEY TAKEAWAYS:"
  puts "1. Without reducers: Simple replacement (data loss risk)"
  puts "2. With reducers: Intelligent merging (data preservation)"
  puts "3. Built-in reducers: add_messages, append_string, merge_hash"
  puts "4. Custom reducers: Define your own combination logic"
  puts "5. Graph workflows: Reducers prevent data loss between nodes"
  puts "6. Immutable updates: Thread-safe and predictable"
  puts "=" * 80
end

# Run the complete tutorial
if __FILE__ == $0
  run_all_examples
end