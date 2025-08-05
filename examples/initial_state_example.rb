#!/usr/bin/env ruby

require_relative '../lib/langgraph_rb'

# Custom state class for advanced initial state management
class TaskManagerState < LangGraphRB::State
  def initialize(schema = {}, reducers = nil)
    # Define default reducers for this state class
    reducers ||= {
      tasks: LangGraphRB::State.add_messages,  # Tasks will be accumulated
      history: LangGraphRB::State.add_messages,  # History will be accumulated  
      metrics: LangGraphRB::State.merge_hash,    # Metrics will be merged
      tags: ->(old, new) { (old || []) | (new || []) }  # Custom reducer: union of arrays
    }
    super(schema, reducers)
  end
end

# Example 1: Basic Initial State - Simple Hash
def example_1_basic_initial_state
  puts "\n" + "=" * 70
  puts "📋 EXAMPLE 1: Basic Initial State with Simple Hash"
  puts "=" * 70
  
  # Create a simple graph that processes user requests
  graph = LangGraphRB::Graph.new do
    node :validate_input do |state|
      input = state[:user_input]
      
      puts "🔍 Validating input: '#{input}'"
      
      if input.nil? || input.strip.empty?
        {
          valid: false,
          error: "Input cannot be empty",
          validation_time: Time.now
        }
      else
        {
          valid: true,
          processed_input: input.strip.downcase,
          validation_time: Time.now
        }
      end
    end
    
    node :process_request do |state|
      unless state[:valid]
        { error: "Cannot process invalid input" }
      else
        input = state[:processed_input]
        puts "⚙️  Processing: #{input}"
        
        {
          result: "Processed: #{input}",
          processing_time: Time.now,
          word_count: input.split.length
        }
      end
    end
    
    node :generate_response do |state|
      if state[:error]
        { response: "Error: #{state[:error]}" }
      else
        response = "✅ #{state[:result]} (#{state[:word_count]} words)"
        puts "📤 Generated response: #{response}"
        
        {
          response: response,
          completed_at: Time.now,
          success: true
        }
      end
    end
    
    set_entry_point :validate_input
    edge :validate_input, :process_request
    edge :process_request, :generate_response
    set_finish_point :generate_response
  end
  
  graph.compile!
  
  # Test with different initial states
  test_cases = [
    { user_input: "Hello World" },              # Valid input
    { user_input: "" },                        # Empty input
    { user_input: "  Process This Request  " }, # Input with whitespace
    { user_input: nil }                        # Nil input
  ]
  
  test_cases.each_with_index do |initial_state, i|
    puts "\n--- Test Case #{i + 1}: #{initial_state.inspect} ---"
    
    result = graph.invoke(initial_state)
    
    puts "Final state keys: #{result.keys.sort}"
    puts "Success: #{result[:success] || false}"
    puts "Response: #{result[:response]}" if result[:response]
    puts "Error: #{result[:error]}" if result[:error]
  end
  
  puts "\n✅ Example 1 completed!"
end

# Example 2: Initial State with Custom Reducers
def example_2_custom_reducers
  puts "\n" + "=" * 70
  puts "📊 EXAMPLE 2: Initial State with Custom Reducers"
  puts "=" * 70
  
  # Create a graph that accumulates data using reducers
  graph = LangGraphRB::Graph.new(state_class: LangGraphRB::State) do
    node :collect_user_info do |state|
      puts "👤 Collecting user info from: #{state[:source]}"
      
      case state[:source]
      when 'profile'
        {
          user_data: { name: state[:name], email: state[:email] },
          sources: ['profile'],
          collection_count: 1
        }
      when 'preferences'  
        {
          user_data: { theme: 'dark', language: 'en' },
          sources: ['preferences'],
          collection_count: 1
        }
      when 'activity'
        {
          user_data: { last_login: Time.now, login_count: 42 },
          sources: ['activity'],
          collection_count: 1
        }
      else
        { sources: ['unknown'], collection_count: 1 }
      end
    end
    
    node :aggregate_data do |state|
      puts "📊 Aggregating collected data"
      
      {
        aggregated: true,
        total_sources: (state[:sources] || []).length,
        final_user_data: state[:user_data] || {},
        processing_completed_at: Time.now
      }
    end
    
    set_entry_point :collect_user_info
    edge :collect_user_info, :aggregate_data
    set_finish_point :aggregate_data
  end
  
  graph.compile!
  
  # Initial state with reducers defined
  initial_state_with_reducers = LangGraphRB::State.new(
    { 
      sources: [],
      user_data: {},
      collection_count: 0
    },
    {
      sources: ->(old, new) { (old || []) + (new || []) },  # Accumulate sources
      user_data: LangGraphRB::State.merge_hash,             # Merge user data
      collection_count: ->(old, new) { (old || 0) + (new || 0) }  # Sum counts
    }
  )
  
  # Test multiple data collection scenarios
  scenarios = [
    { source: 'profile', name: 'John Doe', email: 'john@example.com' },
    { source: 'preferences' },
    { source: 'activity' }
  ]
  
  scenarios.each_with_index do |scenario, i|
    puts "\n--- Scenario #{i + 1}: #{scenario[:source]} data ---"
    
    # Create a copy of the initial state for this scenario
    test_state = initial_state_with_reducers.merge_delta(scenario)
    
    result = graph.invoke(test_state)
    
    puts "Sources collected: #{result[:sources]}"
    puts "Total sources: #{result[:total_sources]}"
    puts "Collection count: #{result[:collection_count]}"
    puts "User data: #{result[:final_user_data]}"
  end
  
  puts "\n✅ Example 2 completed!"
end

# Example 3: Advanced Initial State with Custom State Class
def example_3_custom_state_class
  puts "\n" + "=" * 70
  puts "🏗️  EXAMPLE 3: Advanced Initial State with Custom State Class"
  puts "=" * 70
  
  # Create a task management graph using custom state class
  graph = LangGraphRB::Graph.new(state_class: TaskManagerState) do
    node :add_task do |state|
      task_title = state[:new_task]
      unless task_title
        { error: "No task provided" }
      else
        puts "➕ Adding task: #{task_title}"
        
        new_task = {
          id: SecureRandom.hex(4),
          title: task_title,
          created_at: Time.now,
          status: 'pending'
        }
        
        {
          tasks: [new_task],  # Will be accumulated due to reducer
          history: ["Task '#{task_title}' added"],
          metrics: { total_added: 1, last_added_at: Time.now },
          tags: state[:task_tags] || []
        }
      end
    end
    
    node :update_metrics do |state|
      task_count = (state[:tasks] || []).length
      
      puts "📈 Updating metrics: #{task_count} total tasks"
      
      {
        metrics: { 
          task_count: task_count,
          updated_at: Time.now,
          active_tasks: (state[:tasks] || []).count { |t| t[:status] == 'pending' }
        },
        history: ["Metrics updated: #{task_count} tasks total"]
      }
    end
    
    node :generate_summary do |state|
      tasks = state[:tasks] || []
      history = state[:history] || []
      metrics = state[:metrics] || {}
      tags = state[:tags] || []
      
      puts "📋 Generating summary"
      
      summary = {
        total_tasks: tasks.length,
        total_history_events: history.length,
        unique_tags: tags.uniq.length,
        latest_metric_update: metrics[:updated_at],
        task_titles: tasks.map { |t| t[:title] }
      }
      
      {
        summary: summary,
        history: ["Summary generated with #{tasks.length} tasks"]
      }
    end
    
    set_entry_point :add_task
    edge :add_task, :update_metrics
    edge :update_metrics, :generate_summary
    set_finish_point :generate_summary
  end
  
  graph.compile!
  
  # Test with rich initial state
  rich_initial_state = {
    # Existing data that will be preserved and extended
    tasks: [
      { id: 'existing-1', title: 'Review code', status: 'completed', created_at: Time.now - 3600 }
    ],
    history: ['System initialized', 'Loaded existing tasks'],
    metrics: { system_start_time: Time.now - 7200 },
    tags: ['work', 'priority'],
    
    # New data for current operation
    new_task: 'Write documentation',
    task_tags: ['documentation', 'writing']
  }
  
  puts "Initial state structure:"
  puts "  Existing tasks: 1"
  puts "  History events: 2" 
  puts "  Existing tags: #{rich_initial_state[:tags]}"
  puts "  New task: #{rich_initial_state[:new_task]}"
  puts "  New tags: #{rich_initial_state[:task_tags]}"
  
  result = graph.invoke(rich_initial_state)
  
  puts "\n📊 Final Results:"
  puts "Total tasks: #{result[:summary][:total_tasks]}"
  puts "Task titles: #{result[:summary][:task_titles]}"
  puts "History events: #{result[:summary][:total_history_events]}"
  puts "Unique tags: #{result[:summary][:unique_tags]}"
  puts "Final tags: #{result[:tags]&.uniq}"
  
  puts "\n🔍 Detailed final state:"
  result[:tasks]&.each_with_index do |task, i|
    puts "  Task #{i+1}: #{task[:title]} (#{task[:status]})"
  end
  
  puts "\n📜 History:"
  result[:history]&.each_with_index do |event, i|
    puts "  #{i+1}. #{event}"
  end
  
  puts "\n✅ Example 3 completed!"
end

# Example 4: Dynamic Initial State with Conditional Logic
def example_4_dynamic_initial_state
  puts "\n" + "=" * 70
  puts "🔄 EXAMPLE 4: Dynamic Initial State with Conditional Logic"
  puts "=" * 70
  
  # Create a graph that behaves differently based on initial state
  graph = LangGraphRB::Graph.new do
    node :analyze_context do |state|
      user_type = state[:user_type]
      priority = state[:priority] || 'normal'
      
      puts "🔍 Analyzing context: user_type=#{user_type}, priority=#{priority}"
      
      context = case user_type
               when 'admin'
                 { access_level: 'full', can_modify: true, queue_position: 0 }
               when 'premium'
                 { access_level: 'enhanced', can_modify: true, queue_position: 1 }
               when 'standard'
                 { access_level: 'basic', can_modify: false, queue_position: 2 }
               else
                 { access_level: 'guest', can_modify: false, queue_position: 3 }
               end
      
      # Priority affects queue position
      if priority == 'high'
        context[:queue_position] = [context[:queue_position] - 1, 0].max
      end
      
      context.merge({
        context_analyzed: true,
        analysis_time: Time.now
      })
    end
    
    node :route_request do |state|
      access_level = state[:access_level]
      can_modify = state[:can_modify]
      
      puts "🚦 Routing request for access_level: #{access_level}"
      
      route = if access_level == 'full'
                'admin_flow'
              elsif can_modify
                'user_flow'
              else
                'readonly_flow'
              end
      
      {
        route: route,
        routing_time: Time.now,
        estimated_processing_time: state[:queue_position] * 0.5
      }
    end
    
    node :process_request do |state|
      route = state[:route]
      
      puts "⚙️  Processing via #{route}"
      
      result = case route
              when 'admin_flow'
                'Full admin access granted - all operations available'
              when 'user_flow'  
                'User access granted - modification operations available'
              when 'readonly_flow'
                'Read-only access granted - viewing operations only'
              else
                'Unknown route - access denied'
              end
      
      {
        result: result,
        processed_at: Time.now,
        success: true
      }
    end
    
    set_entry_point :analyze_context
    edge :analyze_context, :route_request
    edge :route_request, :process_request
    set_finish_point :process_request
  end
  
  graph.compile!
  
  # Test different user scenarios with varying initial states
  user_scenarios = [
    { 
      name: "Admin User (High Priority)",
      initial_state: { user_type: 'admin', priority: 'high', request_id: 'REQ-001' }
    },
    {
      name: "Premium User (Normal Priority)", 
      initial_state: { user_type: 'premium', priority: 'normal', request_id: 'REQ-002' }
    },
    {
      name: "Standard User (Low Priority)",
      initial_state: { user_type: 'standard', priority: 'low', request_id: 'REQ-003' }
    },
    {
      name: "Guest User (No Priority Set)",
      initial_state: { user_type: 'guest', request_id: 'REQ-004' }
    },
    {
      name: "Unknown User Type",
      initial_state: { user_type: 'unknown', priority: 'high', request_id: 'REQ-005' }
    }
  ]
  
  user_scenarios.each_with_index do |scenario, i|
    puts "\n--- #{scenario[:name]} ---"
    puts "Initial state: #{scenario[:initial_state]}"
    
    result = graph.invoke(scenario[:initial_state])
    
    puts "Access level: #{result[:access_level]}"
    puts "Can modify: #{result[:can_modify]}"
    puts "Queue position: #{result[:queue_position]}"
    puts "Route: #{result[:route]}"
    puts "Result: #{result[:result]}"
    puts "Est. processing time: #{result[:estimated_processing_time]}s"
  end
  
  puts "\n✅ Example 4 completed!"
end

# Example 5: Initial State Validation and Error Handling
def example_5_state_validation
  puts "\n" + "=" * 70
  puts "✅ EXAMPLE 5: Initial State Validation and Error Handling"  
  puts "=" * 70
  
  # Create a graph with comprehensive state validation
  graph = LangGraphRB::Graph.new do
    node :validate_required_fields do |state|
      puts "🔍 Validating required fields"
      
      required_fields = [:user_id, :action, :timestamp]
      missing_fields = required_fields.select { |field| state[field].nil? }
      
      if missing_fields.any?
        {
          valid: false,
          error: "Missing required fields: #{missing_fields.join(', ')}",
          error_type: 'validation_error'
        }
      else
        {
          valid: true,
          validated_at: Time.now,
          validation_passed: true
        }
      end
    end
    
    node :validate_data_types do |state|
      unless state[:valid]  # Skip if already invalid
        state
      else
        puts "🔢 Validating data types"
        
        errors = []
        
        # Validate user_id is numeric
        unless state[:user_id].is_a?(Numeric) || state[:user_id].to_s.match?(/^\d+$/)
          errors << "user_id must be numeric"
        end
        
        # Validate action is a valid string
        unless state[:action].is_a?(String) && !state[:action].strip.empty?
          errors << "action must be a non-empty string"
        end
        
        # Validate timestamp is a time-like object
        unless state[:timestamp].is_a?(Time)
          begin
            Time.parse(state[:timestamp].to_s) if state[:timestamp]
          rescue
            errors << "timestamp must be a valid time format"
          end
        end
        
        if errors.any?
          {
            valid: false,
            error: "Data type validation failed: #{errors.join(', ')}",
            error_type: 'type_error'
          }
        else
          {
            type_validation_passed: true,
            all_validations_passed: true
          }
        end
      end
    end
    
    node :process_valid_state do |state|
      unless state[:all_validations_passed]
        state
      else
        puts "✅ Processing valid state"
        
        {
          processed: true,
          user_id: state[:user_id].to_i,
          action: state[:action].upcase,
          parsed_timestamp: state[:timestamp].is_a?(Time) ? state[:timestamp] : Time.parse(state[:timestamp].to_s),
          processing_completed_at: Time.now,
          success: true
        }
      end
    end
    
    node :handle_error do |state|
      if state[:success]  # Skip if processing succeeded
        state
      else
        puts "❌ Handling validation error"
        
        {
          error_handled: true,
          error_logged_at: Time.now,
          suggested_fix: case state[:error_type]
                        when 'validation_error'
                          'Please ensure all required fields are provided'
                        when 'type_error'  
                          'Please check data types match expected formats'
                        else
                          'Please review your input data'
                        end
        }
      end
    end
    
    set_entry_point :validate_required_fields
    edge :validate_required_fields, :validate_data_types
    edge :validate_data_types, :process_valid_state
    edge :process_valid_state, :handle_error
    set_finish_point :handle_error
  end
  
  graph.compile!
  
  # Test various initial state scenarios - valid and invalid
  test_scenarios = [
    {
      name: "Valid State",
      state: { user_id: 123, action: "login", timestamp: "2024-01-15 10:30:00" }
    },
    {
      name: "Missing Required Field", 
      state: { user_id: 123, action: "login" }  # missing timestamp
    },
    {
      name: "Invalid Data Types",
      state: { user_id: "not-a-number", action: "", timestamp: "invalid-time" }
    },
    {
      name: "Completely Empty State",
      state: {}
    },
    {
      name: "Partial Valid State",
      state: { user_id: "456", action: "logout", timestamp: Time.now }
    }
  ]
  
  test_scenarios.each do |scenario|
    puts "\n--- Testing: #{scenario[:name]} ---"
    puts "Input: #{scenario[:state]}"
    
    result = graph.invoke(scenario[:state])
    
    if result[:success]
      puts "✅ SUCCESS!"
      puts "  Processed user_id: #{result[:user_id]}"
      puts "  Processed action: #{result[:action]}"
      puts "  Parsed timestamp: #{result[:parsed_timestamp]}"
    else
      puts "❌ VALIDATION FAILED!"
      puts "  Error: #{result[:error]}"
      puts "  Error type: #{result[:error_type]}"
      puts "  Suggested fix: #{result[:suggested_fix]}" if result[:suggested_fix]
    end
  end
  
  puts "\n✅ Example 5 completed!"
end

# Main execution
def main
  puts "🚀 LangGraphRB Initial State Examples"
  puts "======================================"
  puts 
  puts "This example demonstrates various ways to work with initial state:"
  puts "1. Basic initial state with simple hash"
  puts "2. Initial state with custom reducers" 
  puts "3. Advanced initial state with custom state class"
  puts "4. Dynamic initial state with conditional logic"
  puts "5. Initial state validation and error handling"
  puts
  
  example_1_basic_initial_state
  example_2_custom_reducers  
  example_3_custom_state_class
  example_4_dynamic_initial_state
  example_5_state_validation
  
  puts "\n" + "=" * 70
  puts "🎉 All Initial State Examples Completed!"
  puts "=" * 70
  puts
  puts "Key Takeaways:"
  puts "• Initial state can be a simple hash passed to graph.invoke()"
  puts "• Use reducers to control how state updates are merged"
  puts "• Custom state classes can provide default reducers"
  puts "• Initial state affects graph execution flow and routing"
  puts "• Always validate initial state for robust applications"
  puts "• LangGraphRB::State provides common reducers like add_messages"
end

# Run the examples
if __FILE__ == $0
  main
end