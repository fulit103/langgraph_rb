require 'logger'

module LangGraphRB
  module Observers
    # File and stdout logging observer
    class LoggerObserver < BaseObserver
      def initialize(logger: nil, level: :info, format: :text)
        @logger = logger || Logger.new($stdout)
        @level = level
        @format = format
        @logger.level = Logger.const_get(level.to_s.upcase)
      end

      def on_graph_start(event)
        log(:info, "Graph execution started", event.to_h)
      end

      def on_graph_end(event)
        log(:info, "Graph execution completed", event.to_h)
      end

      def on_node_start(event)
        log(:debug, "Node execution started: #{event.node_name}", event.to_h)
      end

      def on_node_end(event)
        duration_ms = event.duration ? (event.duration * 1000).round(2) : 'unknown'
        log(:info, "Node completed: #{event.node_name} (#{duration_ms}ms)", event.to_h)
      end

      def on_node_error(event)
        log(:error, "Node error: #{event.node_name} - #{event.error&.message}", event.to_h)
      end

      def on_step_complete(event)
        log(:debug, "Step #{event.step_number} completed with #{event.completed_nodes.length} nodes", event.to_h)
      end

      def on_interrupt(event)
        log(:warn, "Execution interrupted: #{event[:message]}", event)
      end

      private

      def log(level, message, data)
        case @format
        when :json
          @logger.send(level, { message: message, data: sanitize_data(data) }.to_json)
        else
          @logger.send(level, "#{message} | #{format_data(data)}")
        end
      end

      def format_data(data)
        relevant_fields = data.select { |k, v| [:thread_id, :step_number, :node_name, :duration_ms].include?(k) && v }
        relevant_fields.map { |k, v| "#{k}=#{v}" }.join(" ")
      end

      def sanitize_data(data)
        data.transform_values do |value|
          case value
          when Hash
            sanitize_state(value, max_size: 500)
          else
            value
          end
        end
      end
    end
  end
end 