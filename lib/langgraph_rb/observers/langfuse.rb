require 'langfuse'

module LangGraphRB
  module Observers
    # Langfuse observer that captures graph, node, and LLM events.
    # - Creates a Langfuse trace for each graph run (thread_id)
    # - Creates spans per node execution and links LLM generations to spans
    # - Thread-safe and resilient to Langfuse client errors
    class LangfuseObserver < BaseObserver
      def initialize(name: 'langgraph-run')
        @name = name
        @trace = nil
        @trace_mutex = Mutex.new

        # Maintain a stack per node_name to safely handle parallel executions
        # { Symbol(String) => [ { span: <Span>, generation: <Generation>|nil } ] }
        @records_by_node = Hash.new { |h, k| h[k] = [] }
        @records_mutex = Mutex.new
      end

      # Graph lifecycle
      def on_graph_start(event)
        ensure_trace!(event)
      rescue => _e
        # Swallow observer errors to avoid impacting execution
      end

      def on_graph_end(event)
        return unless @trace
        Langfuse.trace(id: @trace.id, output: safe_state(event.initial_state))
      rescue => _e
      end

      # Node lifecycle
      def on_node_start(event)
        return if event.node_name == :__start__

        trace = ensure_trace!(event)
        return unless trace

        span = Langfuse.span(
          name: event.node_name.to_s,
          trace_id: trace.id,
          metadata: event.to_h
        )

        # Track record on a stack keyed by node_name
        with_records_lock do
          @records_by_node[event.node_name] << { span: span, generation: nil }
        end

        Langfuse.update_span(span)
      rescue => _e
      end

      def on_node_end(event)
        return if event.node_name == :__start__

        record = with_records_lock do
          @records_by_node[event.node_name].pop
        end

        span = record && record[:span]
        return unless span

        data = event.to_h
        span.input = safe_state(data[:state_before])
        span.output = safe_state(data[:state_after])
        span.metadata = data
        span.end_time = Time.now.utc
        Langfuse.update_span(span)
      rescue => _e
      end

      def on_node_error(event)
        return if event.node_name == :__start__

        record = with_records_lock do
          @records_by_node[event.node_name].pop
        end

        span = record && record[:span]
        return unless span

        span.metadata = event.to_h
        span.end_time = Time.now.utc
        Langfuse.update_span(span)
      rescue => _e
      end

      # LLM lifecycle (called directly by LLM clients)
      def on_llm_request(data, node_name)
        record = with_records_lock do
          stack = @records_by_node[node_name]
          stack.empty? ? nil : stack[-1]
        end
        return unless record && record[:span]

        # Prefer normalized payload from LLMBase implementations (e.g., ChatOpenAI)
        input_payload = if data.is_a?(Hash)
          data[:input] || data[:messages] || (data[:request] && data[:request][:messages])
        else
          data
        end

        generation = Langfuse.generation(
          name: "llm-request-#{node_name}",
          trace_id: @trace&.id,
          parent_observation_id: record[:span].id,
          model: data[:model],
          input: input_payload,
          metadata: (data.respond_to?(:to_h) ? data.to_h : data)
        )

        with_records_lock do
          record[:generation] = generation
        end
      rescue => _e
      end

      def on_llm_response(data, node_name)
        record = with_records_lock do
          stack = @records_by_node[node_name]
          stack.empty? ? nil : stack[-1]
        end
        return unless record && record[:generation]

        generation = record[:generation]

        if data.is_a?(Hash)
          # Prefer normalized payload keys first
          if data.key?(:output)
            generation.output = data[:output]
          else
            # Fallback to OpenAI-style response structure
            generation.output = data.dig(:choices, 0, :message, :content)
          end

          # Usage: support both normalized top-level and OpenAI usage block
          prompt_tokens = data[:prompt_tokens] || data.dig(:usage, :prompt_tokens)
          completion_tokens = data[:completion_tokens] || data.dig(:usage, :completion_tokens)
          total_tokens = data[:total_tokens] || data.dig(:usage, :total_tokens)

          if prompt_tokens || completion_tokens || total_tokens
            begin
              generation.usage = Langfuse::Models::Usage.new(
                prompt_tokens: prompt_tokens,
                completion_tokens: completion_tokens,
                total_tokens: total_tokens
              )
            rescue => _e
              # best-effort usage mapping
            end
          end
        else
          generation.output = data
        end

        generation.end_time = Time.now.utc
        Langfuse.update_generation(generation)

        with_records_lock do
          record[:generation] = nil
        end
      rescue => _e
      end

      def on_llm_error(data, node_name)
        record = with_records_lock do
          stack = @records_by_node[node_name]
          stack.empty? ? nil : stack[-1]
        end
        return unless record && record[:generation]

        generation = record[:generation]        
        generation.output = data[:error]
        generation.end_time = Time.now.utc
        Langfuse.update_generation(generation)

        with_records_lock do
          record[:generation] = nil
        end
      rescue => _e
      end

      private

      def ensure_trace!(event)
        return @trace if @trace
        @trace_mutex.synchronize do
          return @trace if @trace
          data = event.to_h
          @trace = Langfuse.trace(
            name: @name,
            thread_id: data[:thread_id],
            metadata: data,
            input: safe_state(data[:initial_state])
          )
        end
        @trace
      end

      def with_records_lock
        @records_mutex.synchronize do
          yield
        end
      end

      def safe_state(state)
        return nil if state.nil?
        if state.respond_to?(:to_h)
          state.to_h
        else
          state
        end
      rescue => _e
        nil
      end
    end
  end
end


