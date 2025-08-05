require 'thread'
require 'json'
require 'time'

module LangGraphRB
  class Runner
    attr_reader :graph, :store, :thread_id

    def initialize(graph, store:, thread_id:, observers: [])
      @graph = graph
      @store = store
      @thread_id = thread_id
      @step_number = 0
      @execution_queue = Queue.new
      @interrupt_handler = nil
      @observers = Array(observers)
    end

    # Synchronous execution
    def invoke(initial_state, context: nil)
      result = nil
      
      stream(initial_state, context: context) do |step_result|
        result = step_result
      end
      
      result[:state]
    end

    # Streaming execution with optional block for receiving intermediate results
    def stream(initial_state, context: nil, &block)
      notify_graph_start(initial_state, context)
      
      @step_number = 0
      current_state = initial_state
      
      # Initialize execution queue with START node
      active_executions = [
        ExecutionFrame.new(Graph::START, current_state, 0)
      ]

      loop do
        break if active_executions.empty?
        
        # Execute current super-step (all nodes at current level in parallel)
        step_results = execute_super_step(active_executions, context)
        break if step_results.empty?
        
        @step_number += 1
        
        # Process results and determine next nodes
        next_active = []
        final_state = nil
        
        step_results.each do |result|
          case result[:type]
          when :completed
            # Node completed normally
            if result[:next_destination]
              # Command specified explicit destination
              dest_name = result[:next_destination]
              dest_state = result[:state]
              
              if dest_name == Graph::FINISH
                final_state = dest_state
              else
                next_active << ExecutionFrame.new(dest_name, dest_state, @step_number)
              end
            else
              # Use normal edge routing
              next_destinations = determine_next_destinations(
                result[:node_name], 
                result[:state], 
                context
              )
              
              next_destinations.each do |dest_name, dest_state|
                if dest_name == Graph::FINISH
                  final_state = dest_state
                else
                  next_active << ExecutionFrame.new(dest_name, dest_state, @step_number)
                end
              end
            end
            
          when :send
            # Handle Send commands (map-reduce)
            result[:sends].each do |send_cmd|
              payload_state = result[:state].merge_delta(send_cmd.payload)
              next_active << ExecutionFrame.new(send_cmd.to, payload_state, @step_number)
            end
            
          when :interrupt
            # Handle human-in-the-loop interrupts
            if @interrupt_handler
              user_input = @interrupt_handler.call(result[:interrupt])
              # Continue with user input merged into state
              updated_state = result[:state].merge_delta(user_input || {})
              next_active << ExecutionFrame.new(result[:node_name], updated_state, @step_number)
            else
              # No interrupt handler, treat as completion
              final_state = result[:state]
            end
            
          when :error
            raise result[:error]
          end
        end
        
        # Save checkpoint
        checkpoint_state = final_state || (next_active.first&.state) || current_state
        save_checkpoint(checkpoint_state, @step_number)
        
        # Yield intermediate result if block given
        if block
          yield({
            step: @step_number,
            state: checkpoint_state,
            active_nodes: next_active.map(&:node_name),
            completed: next_active.empty?
          })
        end
        
        # Update for next iteration
        current_state = checkpoint_state
        active_executions = next_active
        
        # Break if we reached END
        break if final_state
      end
      
      result = {
        state: current_state,
        step_number: @step_number,
        thread_id: @thread_id
      }
      
      notify_graph_end(current_state)
      result
    rescue => error
      notify_graph_end(current_state || initial_state)
      raise
    end

    # Resume from checkpoint
    def resume(additional_input = {}, context: nil)
      checkpoint = @store.load(@thread_id)
      raise GraphError, "No checkpoint found for thread #{@thread_id}" unless checkpoint
      
      @step_number = checkpoint[:step_number]
      resumed_state = checkpoint[:state].merge_delta(additional_input)
      
      # Resume execution from where we left off
      stream(resumed_state, context: context)
    end

    # Set interrupt handler for human-in-the-loop
    def on_interrupt(&handler)
      @interrupt_handler = handler
    end

    private

    def notify_observers(method, event)
      @observers.each do |observer|
        begin
          observer.send(method, event)
        rescue => e
          # Log observer errors but don't fail execution
          $stderr.puts "Observer error in #{observer.class}##{method}: #{e.message}"
        end
      end
    end

    def notify_graph_start(initial_state, context)
      event = Observers::GraphEvent.new(
        type: :start,
        graph: @graph,
        initial_state: initial_state,
        context: context,
        thread_id: @thread_id
      )
      notify_observers(:on_graph_start, event)
    end

    def notify_graph_end(final_state)
      event = Observers::GraphEvent.new(
        type: :end,
        graph: @graph,
        initial_state: final_state,
        thread_id: @thread_id
      )
      notify_observers(:on_graph_end, event)
    end

    def notify_node_start(node, state, context)
      event = Observers::NodeEvent.new(
        type: :start,
        node_name: node.name,
        node_class: node.class,
        state_before: state,
        context: context,
        thread_id: @thread_id,
        step_number: @step_number
      )
      notify_observers(:on_node_start, event)
    end

    def notify_node_end(node, state_before, state_after, result, duration)
      event = Observers::NodeEvent.new(
        type: :end,
        node_name: node.name,
        node_class: node.class,
        state_before: state_before,
        state_after: state_after,
        result: result,
        duration: duration,
        thread_id: @thread_id,
        step_number: @step_number
      )
      notify_observers(:on_node_end, event)
    end

    def notify_node_error(node, state, error)
      event = Observers::NodeEvent.new(
        type: :error,
        node_name: node.name,
        node_class: node.class,
        state_before: state,
        error: error,
        thread_id: @thread_id,
        step_number: @step_number
      )
      notify_observers(:on_node_error, event)
    end

    # Execute all nodes in the current super-step in parallel
    def execute_super_step(active_executions, context)
      return [] if active_executions.empty?
      
      # Group by node name to handle potential duplicates
      grouped_executions = active_executions.group_by(&:node_name)
      
      results = []
      threads = []
      
      grouped_executions.each do |node_name, executions|
        node = @graph.nodes[node_name]
        next unless node  # Skip if node doesn't exist
        
        # Execute each frame for this node
        executions.each do |frame|
          thread = Thread.new do
            execute_node_safely(node, frame.state, context, frame.step)
          end
          threads << thread
        end
      end
      
      # Wait for all threads to complete
      threads.each do |thread|
        result = thread.join.value
        results << result if result
      end
      
      results
    end

    # Safely execute a single node
    def execute_node_safely(node, state, context, step)
      notify_node_start(node, state, context)
      
      start_time = Time.now
      begin
        result = node.call(state, context: context)
        duration = Time.now - start_time
        
        processed_result = process_node_result(node.name, state, result, step)
        
        # Extract final state from processed result
        final_state = case processed_result[:type]
                     when :completed
                       processed_result[:state]
                     else
                       state
                     end
        
        notify_node_end(node, state, final_state, result, duration)
        processed_result
      rescue => error
        duration = Time.now - start_time
        notify_node_error(node, state, error)
        
        {
          type: :error,
          node_name: node.name,
          state: state,
          step: step,
          error: error
        }
      end
    end

    # Process the result from a node execution
    def process_node_result(node_name, original_state, result, step)
      case result
      when Command
        # Handle Command (update + goto)
        updated_state = original_state.merge_delta(result.update)
        
        if result.goto
          determine_next_destinations(node_name, updated_state, nil, forced_destination: result.goto)
            .map do |dest_name, dest_state|
              {
                type: :completed,
                node_name: node_name,
                state: dest_state,
                step: step,
                next_destination: dest_name
              }
            end.first
        else
          {
            type: :completed,
            node_name: node_name,
            state: updated_state,
            step: step
          }
        end
        
      when Send
        # Handle single Send
        {
          type: :send,
          node_name: node_name,
          state: original_state,
          step: step,
          sends: [result]
        }
        
      when MultiSend
        # Handle multiple Sends
        {
          type: :send,
          node_name: node_name,
          state: original_state,
          step: step,
          sends: result.sends
        }
        
      when Interrupt
        # Handle interrupt for human-in-the-loop
        {
          type: :interrupt,
          node_name: node_name,
          state: original_state,
          step: step,
          interrupt: result
        }
        
      when Hash
        # Handle simple state delta
        updated_state = original_state.merge_delta(result)
        {
          type: :completed,
          node_name: node_name,
          state: updated_state,
          step: step
        }
        
      else
        # Handle other return values
        {
          type: :completed,
          node_name: node_name,
          state: original_state,
          step: step
        }
      end
    end

    # Determine next destinations based on edges
    def determine_next_destinations(from_node, state, context, forced_destination: nil)
      if forced_destination
        return [[forced_destination, state]]
      end
      
      edges = @graph.get_edges_from(from_node)
      destinations = []
      
      edges.each do |edge|
        case edge
        when Edge
          destinations << [edge.to, state]
          
        when ConditionalEdge
          routes = edge.route(state, context: context)
          routes.each do |dest|
            destinations << [dest, state]
          end
          
        when FanOutEdge
          routes = edge.route(state, context: context)
          routes.each do |dest|
            destinations << [dest, state]
          end
        end
      end
      
      # Default to FINISH if no edges defined
      destinations.empty? ? [[Graph::FINISH, state]] : destinations
    end

    # Save execution checkpoint
    def save_checkpoint(state, step_number)
      @store.save(@thread_id, state, step_number, {
        timestamp: Time.now,
        graph_class: @graph.class.name
      })
    end

    # Execution frame for tracking active node executions
    class ExecutionFrame
      attr_reader :node_name, :state, :step

      def initialize(node_name, state, step)
        @node_name = node_name.to_sym
        @state = state
        @step = step
      end

      def to_s
        "#<ExecutionFrame node: #{@node_name}, step: #{@step}>"
      end
    end
  end

  # Thread-safe execution result collector
  class ResultCollector
    def initialize
      @results = []
      @mutex = Mutex.new
    end

    def add(result)
      @mutex.synchronize do
        @results << result
      end
    end

    def all
      @mutex.synchronize do
        @results.dup
      end
    end

    def clear
      @mutex.synchronize do
        @results.clear
      end
    end
  end
end 