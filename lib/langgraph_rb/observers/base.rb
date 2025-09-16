require 'json'
require 'time'

module LangGraphRB
  module Observers
    # Abstract base class for observability implementations
    class BaseObserver
      # Called when graph execution starts
      def on_graph_start(event)
        # Override in subclasses
      end

      # Called when graph execution completes
      def on_graph_end(event)
        # Override in subclasses
      end

      # Called when a node execution starts
      def on_node_start(event)
        # Override in subclasses
      end

      # Called when a node execution completes successfully
      def on_node_end(event)
        # Override in subclasses
      end

      # Called when a node execution encounters an error
      def on_node_error(event)
        # Override in subclasses
      end

      # Called when a step completes (multiple nodes may execute in parallel)
      def on_step_complete(event)
        # Override in subclasses
      end

      # Called when state changes occur
      def on_state_change(event)
        # Override in subclasses
      end

      # Called when commands are processed (Send, Command, etc.)
      def on_command_processed(event)
        # Override in subclasses
      end

      # Called when interrupts occur
      def on_interrupt(event)
        # Override in subclasses
      end

      # Called when checkpoints are saved
      def on_checkpoint_saved(event)
        # Override in subclasses
      end

      # Shutdown hook for cleanup
      def shutdown
        # Override in subclasses if cleanup needed
      end

      # Called when LLM requests occur
      def on_llm_request(event)
        # Override in subclasses
      end

      # Called when LLM responses occur
      def on_llm_response(event)
        # Override in subclasses
      end

      protected

      # Helper method to create standardized event structure
      def create_event(type, data = {})
        {
          type: type,
          timestamp: Time.now.utc.iso8601,
          thread_id: data[:thread_id],
          step_number: data[:step_number],
          **data
        }
      end

      # Helper to sanitize state data (remove sensitive info, limit size)
      def sanitize_state(state, max_size: 1000)
        return nil unless state
        
        state_hash = state.respond_to?(:to_h) ? state.to_h : state
        serialized = state_hash.to_json
        
        if serialized.length > max_size
          { _truncated: true, _size: serialized.length, _preview: serialized[0...max_size] }
        else
          state_hash
        end
      end
    end

    # Event data structures
    class GraphEvent
      attr_reader :type, :graph, :initial_state, :context, :thread_id, :timestamp

      def initialize(type:, graph:, initial_state: nil, context: nil, thread_id: nil)
        @type = type
        @graph = graph
        @initial_state = initial_state
        @context = context
        @thread_id = thread_id
        @timestamp = Time.now.utc
      end

      def to_h
        {
          type: @type,
          graph_class: @graph.class.name,
          node_count: @graph.nodes.size,
          edge_count: @graph.edges.size,
          initial_state: @initial_state,
          context: @context,
          thread_id: @thread_id,
          timestamp: @timestamp.iso8601
        }
      end
    end

    class NodeEvent
      attr_reader :type, :node_name, :node_class, :state_before, :state_after, 
                  :context, :thread_id, :step_number, :duration, :error, :result, :timestamp, :from_node

      def initialize(type:, node_name:, node_class: nil, state_before: nil, state_after: nil,
                     context: nil, thread_id: nil, step_number: nil, duration: nil, 
                     error: nil, result: nil, from_node: nil)
        @type = type
        @node_name = node_name
        @node_class = node_class
        @state_before = state_before
        @state_after = state_after
        @context = context
        @thread_id = thread_id
        @step_number = step_number
        @duration = duration
        @error = error
        @result = result
        @from_node = from_node
        @timestamp = Time.now.utc
      end

      def to_h
        {
          type: @type,
          node_name: @node_name,
          node_class: @node_class&.name,
          from_node: @from_node,
          state_before: @state_before,
          state_after: @state_after,
          context: @context,
          thread_id: @thread_id,
          step_number: @step_number,
          duration_ms: @duration ? (@duration * 1000).round(2) : nil,
          error: @error&.message,
          error_class: @error&.class&.name,
          result_type: @result&.class&.name,
          timestamp: @timestamp.iso8601
        }
      end
    end

    class StepEvent
      attr_reader :type, :step_number, :active_nodes, :completed_nodes, :thread_id, 
                  :state, :duration, :timestamp

      def initialize(type:, step_number:, active_nodes: [], completed_nodes: [], 
                     thread_id: nil, state: nil, duration: nil)
        @type = type
        @step_number = step_number
        @active_nodes = active_nodes
        @completed_nodes = completed_nodes
        @thread_id = thread_id
        @state = state
        @duration = duration
        @timestamp = Time.now.utc
      end

      def to_h
        {
          type: @type,
          step_number: @step_number,
          active_nodes: @active_nodes,
          completed_nodes: @completed_nodes,
          thread_id: @thread_id,
          state: @state,
          duration_ms: @duration ? (@duration * 1000).round(2) : nil,
          timestamp: @timestamp.iso8601
        }
      end
    end
  end
end 