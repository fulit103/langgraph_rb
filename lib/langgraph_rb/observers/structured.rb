require 'json'

module LangGraphRB
  module Observers
    # Structured data observer for APM/monitoring integration
    class StructuredObserver < BaseObserver
      def initialize(sink: nil, format: :json, include_state: false, async: false)
        @sink = sink || $stdout
        @format = format
        @include_state = include_state
        @async = async
        @event_queue = async ? Queue.new : nil
        @worker_thread = start_worker_thread if async
      end

      def on_graph_start(event)
        emit_event(:graph_start, event.to_h)
      end

      def on_graph_end(event)
        emit_event(:graph_end, event.to_h)
      end

      def on_node_start(event)
        emit_event(:node_start, sanitize_event(event.to_h))
      end

      def on_node_end(event)
        emit_event(:node_end, sanitize_event(event.to_h))
      end

      def on_node_error(event)
        emit_event(:node_error, sanitize_event(event.to_h))
      end

      def on_step_complete(event)
        emit_event(:step_complete, sanitize_event(event.to_h))
      end

      def on_command_processed(event)
        emit_event(:command_processed, event)
      end

      def shutdown
        if @async && @worker_thread
          @event_queue << :shutdown
          @worker_thread.join
        end
      end

      private

      def emit_event(type, data)
        event = {
          event_type: type,
          timestamp: Time.now.utc.iso8601,
          **data
        }

        if @async
          @event_queue << event
        else
          write_event(event)
        end
      end

      def write_event(event)
        case @format
        when :json
          @sink.puts(JSON.generate(event))
        when :ndjson
          @sink.puts(JSON.generate(event))
        else
          @sink.puts(event.inspect)
        end
        
        @sink.flush if @sink.respond_to?(:flush)
      end

      def sanitize_event(event_data)
        result = event_data.dup
        
        unless @include_state
          result.delete(:state_before)
          result.delete(:state_after)
          result.delete(:state)
        else
          result[:state_before] = sanitize_state(result[:state_before]) if result[:state_before]
          result[:state_after] = sanitize_state(result[:state_after]) if result[:state_after]
          result[:state] = sanitize_state(result[:state]) if result[:state]
        end
        
        result
      end

      def start_worker_thread
        Thread.new do
          loop do
            event = @event_queue.pop
            break if event == :shutdown
            
            write_event(event)
          rescue => e
            # Log error but continue processing
            $stderr.puts "Observer error: #{e.message}"
          end
        end
      end
    end
  end
end 