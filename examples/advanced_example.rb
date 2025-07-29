#!/usr/bin/env ruby

require_relative '../lib/langgraph_rb'

# Example: Research assistant with parallel processing
def research_assistant_example
  puts "=== Advanced Research Assistant Example ==="
  
  # Mock research tools
  class MockSearchTool
    def self.call(query)
      puts "  🔍 Searching for: #{query}"
      sleep(0.3)  # Simulate API call
      {
        results: [
          "Result 1 for #{query}: Important finding about #{query}",
          "Result 2 for #{query}: Another insight on #{query}",
          "Result 3 for #{query}: #{query} research conclusion"
        ],
        source: "MockSearch"
      }
    end
  end
  
  class MockSummarizer
    def self.call(content)
      puts "  📝 Summarizing content..."
      sleep(0.2)
      {
        summary: "Summary: #{content[:results]&.first&.slice(0, 50)}...",
        word_count: content[:results]&.join(' ')&.length || 0
      }
    end
  end

  # Create graph with parallel processing
  graph = LangGraphRB::Graph.new do
    # Entry point - process research request
    node :process_request do |state|
      query = state[:query]
      puts "📋 Processing research request: #{query}"
      
      # Extract topics for parallel research
      topics = query.downcase.split(/\s+and\s+|\s*,\s*|\s*&\s*/)
      
      puts "  Topics identified: #{topics.inspect}"
      
      {
        original_query: query,
        topics: topics,
        research_tasks: topics.map.with_index { |topic, i| { id: i, topic: topic } }
      }
    end

    # Fan out to parallel research tasks
    node :distribute_research do |state|
      tasks = state[:research_tasks] || []
      
      puts "🔀 Distributing #{tasks.length} research tasks in parallel"
      
      # Create Send commands for each task
      sends = tasks.map do |task|
        LangGraphRB::Send.new(
          to: :research_topic,
          payload: { 
            task_id: task[:id],
            topic: task[:topic],
            parent_query: state[:original_query]
          }
        )
      end
      
      LangGraphRB::MultiSend.new(sends)
    end

    # Parallel research node (will be executed multiple times)
    node :research_topic do |state|
      topic = state[:topic]
      task_id = state[:task_id]
      
      puts "🔬 [Task #{task_id}] Researching: #{topic}"
      
      # Simulate research
      search_results = MockSearchTool.call(topic)
      summary = MockSummarizer.call(search_results)
      
      {
        task_id: task_id,
        topic: topic,
        research_complete: true,
        findings: {
          topic: topic,
          results: search_results[:results],
          summary: summary[:summary],
          word_count: summary[:word_count]
        }
      }
    end

    # Collect and synthesize results
    node :synthesize_results do |state|
      puts "🧩 Synthesizing research results..."
      
      # In a real implementation, this would collect results from all parallel tasks
      # For now, we'll simulate having collected results
      findings = state[:findings] || {}
      
      synthesis = {
        total_topics_researched: 1,  # This would be dynamic in real implementation
        key_findings: findings[:summary] || "Research completed",
        confidence_score: 0.85,
        synthesis_complete: true
      }
      
      puts "  ✅ Synthesis complete - Confidence: #{synthesis[:confidence_score]}"
      
      {
        synthesis: synthesis,
        ready_for_review: true
      }
    end

    # Human review checkpoint
    node :request_human_review do |state|
      puts "👤 Requesting human review of research..."
      
      review_data = {
        findings: state[:synthesis],
        original_query: state[:original_query],
        topics_covered: state[:topics] || [],
        timestamp: Time.now
      }
      
      # Return an interrupt to pause for human input
      LangGraphRB::Commands.interrupt(
        message: "Please review the research findings. Type 'approve' to continue or 'revise' to request changes.",
        data: review_data
      )
    end

    # Process human feedback
    node :process_feedback do |state|
      feedback = state[:human_feedback] || 'approve'
      
      puts "💭 Processing human feedback: #{feedback}"
      
      case feedback.downcase
      when 'approve'
        {
          status: 'approved',
          final_report_ready: true
        }
      when 'revise'
        LangGraphRB::Commands.update_and_goto(
          { status: 'needs_revision', revision_requested: true },
          :process_request  # Go back to start with revisions
        )
      else
        {
          status: 'unclear_feedback',
          needs_clarification: true
        }
      end
    end

    # Generate final report
    node :generate_final_report do |state|
      puts "📑 Generating final research report..."
      
      report = {
        title: "Research Report: #{state[:original_query]}",
        executive_summary: state[:synthesis][:key_findings],
        confidence: state[:synthesis][:confidence_score],
        status: state[:status],
        generated_at: Time.now,
        report_id: SecureRandom.hex(6)
      }
      
      puts "  📋 Report generated: #{report[:report_id]}"
      
      {
        final_report: report,
        completed: true
      }
    end

    # Define the flow
    set_entry_point :process_request
    edge :process_request, :distribute_research
    edge :distribute_research, :research_topic
    edge :research_topic, :synthesize_results
    edge :synthesize_results, :request_human_review
    edge :request_human_review, :process_feedback
    
    # Conditional routing based on feedback
    conditional_edge :process_feedback, ->(state) { 
      case state[:status]
      when 'approved'
        :generate_final_report
      when 'needs_revision'
        :process_request
      else
        :request_human_review
      end
    }
    
    set_finish_point :generate_final_report
  end

  # Compile and set up human-in-the-loop handler
  graph.compile!
  
  puts "\n📊 Research Assistant Graph Structure:"
  puts graph.to_mermaid
  puts
  
  # Set up persistence
  store = LangGraphRB::Stores::InMemoryStore.new
  thread_id = "research_#{SecureRandom.hex(4)}"
  
  # Create runner and set interrupt handler
  runner = LangGraphRB::Runner.new(graph, store: store, thread_id: thread_id)
  
  runner.on_interrupt do |interrupt|
    puts "\n⏸️  EXECUTION PAUSED"
    puts "   Message: #{interrupt.message}"
    puts "   Data: #{interrupt.data.keys.inspect}"
    
    # Simulate human input (in real app, this would be user input)
    puts "\n🤖 Simulating human approval..."
    sleep(1)
    
    { human_feedback: 'approve' }  # Return the human input
  end
  
  # Run the research assistant
  puts "🚀 Starting research assistant..."
  
  result = runner.stream({
    query: "artificial intelligence and machine learning trends"
  }) do |step_result|
    puts "  📊 Step #{step_result[:step]}: #{step_result[:active_nodes].inspect}"
    puts "     Completed: #{step_result[:completed]}"
  end
  
  puts "\n✅ Research completed!"
  puts "Final report ID: #{result[:state][:final_report][:report_id]}"
  puts "Thread ID: #{result[:thread_id]} (can be used to resume if needed)"
  
  # Show checkpoints
  puts "\n📚 Execution checkpoints:"
  store.list_steps(thread_id).each do |step|
    checkpoint = store.load(thread_id, step)
    puts "  Step #{step}: #{checkpoint[:timestamp]} - #{checkpoint[:state].keys.inspect}"
  end
end

# Example of map-reduce pattern with Send commands
def map_reduce_example
  puts "\n=== Map-Reduce Processing Example ==="
  
  # Simulate processing a large dataset
  graph = LangGraphRB::Graph.new do
    node :prepare_data do |state|
      data = state[:input_data] || (1..10).to_a
      chunks = data.each_slice(3).to_a  # Split into chunks of 3
      
      puts "📦 Preparing data for processing: #{chunks.length} chunks"
      
      {
        original_data: data,
        chunks: chunks,
        total_items: data.length
      }
    end

    node :map_phase do |state|
      chunks = state[:chunks] || []
      
      puts "🗺️  Starting map phase with #{chunks.length} chunks"
      
      # Send each chunk to parallel processing
      sends = chunks.map.with_index do |chunk, index|
        LangGraphRB::Send.new(
          to: :process_chunk,
          payload: {
            chunk_id: index,
            chunk_data: chunk,
            chunk_size: chunk.length
          }
        )
      end
      
      LangGraphRB::MultiSend.new(sends)
    end

    node :process_chunk do |state|
      chunk_id = state[:chunk_id]
      chunk_data = state[:chunk_data]
      
      puts "  ⚙️  Processing chunk #{chunk_id}: #{chunk_data.inspect}"
      
      # Simulate processing (square each number)
      processed = chunk_data.map { |x| x * x }
      sum = processed.sum
      
      sleep(0.1)  # Simulate work
      
      {
        chunk_id: chunk_id,
        processed_data: processed,
        chunk_sum: sum,
        processing_complete: true
      }
    end

    node :reduce_phase do |state|
      puts "🔄 Reduce phase - collecting results..."
      
      # In a real implementation, this would collect from all chunks
      processed_data = state[:processed_data] || []
      chunk_sum = state[:chunk_sum] || 0
      
      puts "  📊 Chunk sum: #{chunk_sum}"
      
      {
        partial_results: {
          data: processed_data,
          sum: chunk_sum
        },
        reduce_step_complete: true
      }
    end

    node :final_aggregation do |state|
      puts "🎯 Final aggregation of all results..."
      
      # Simulate final aggregation
      final_result = {
        total_processed_items: state[:total_items] || 0,
        sample_result: state[:partial_results],
        processing_time: Time.now,
        status: 'completed'
      }
      
      puts "  ✅ Processing complete: #{final_result[:total_processed_items]} items"
      
      {
        final_result: final_result,
        completed: true
      }
    end

    # Define flow
    set_entry_point :prepare_data
    edge :prepare_data, :map_phase
    edge :map_phase, :process_chunk
    edge :process_chunk, :reduce_phase
    edge :reduce_phase, :final_aggregation
    set_finish_point :final_aggregation
  end

  graph.compile!
  
  # Execute with timing
  start_time = Time.now
  
  result = graph.invoke({ input_data: (1..12).to_a })
  
  end_time = Time.now
  
  puts "\n⏱️  Processing time: #{(end_time - start_time).round(2)} seconds"
  puts "📋 Final result: #{result[:final_result][:status]}"
  puts "✅ Map-reduce example completed!"
end

# Run examples
if __FILE__ == $0
  research_assistant_example
  map_reduce_example
end 