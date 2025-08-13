require 'opentelemetry/sdk'

module Langgraph
  module Middleware
    class RackTraceContext
      def initialize(app)
        @app = app
        @tracer = ::OpenTelemetry.tracer_provider.tracer('langgraph')
      end

      def call(env)
        @tracer.in_span('rack.request') do
          @app.call(env)
        end
      end
    end
  end
end
