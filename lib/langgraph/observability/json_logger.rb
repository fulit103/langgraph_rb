require 'logger'
require 'json'
require 'time'
require_relative 'config'
require_relative 'redactor'

module Langgraph
  module Observability
    class JsonLogger < ::Logger
      def initialize(io = $stdout, redactor: Redactor.new)
        super(io)
        @redactor = redactor
        self.formatter = proc do |severity, datetime, progname, msg|
          data = base_payload(severity, datetime, msg)
          data = @redactor.redact_hash(data) if @redactor
          JSON.generate(data) + "\n"
        end
      end

      private

      def base_payload(severity, datetime, msg)
        payload = {
          timestamp: datetime.utc.iso8601(3),
          level: severity,
          message: msg.is_a?(String) ? msg : msg.inspect,
          run_id: Thread.current[:langgraph_run_id],
          thread_id: Thread.current.object_id,
          graph_name: Thread.current[:langgraph_graph_name]
        }
        if (span = OpenTelemetry::Trace.current_span) && span.context.valid?
          payload[:trace_id] = span.context.trace_id
          payload[:span_id] = span.context.span_id
        end
        payload
      end
    end
  end
end
