require 'opentelemetry/sdk'
require_relative '../config'
require_relative '../notifications'

module Langgraph
  module Observability
    module Adapters
      module OpenTelemetry
        @run_spans = {}
        class << self
          def subscribe!(tracer_provider: default_tracer_provider)
            @tracer = tracer_provider.tracer('langgraph')
            Notifications.subscribe do |event|
              payload = event.payload
              case event.name
              when 'langgraph.graph.run'
                root_span(payload)
              when 'langgraph.node.run'
                child_span('node.run', payload)
              when 'langgraph.llm.call'
                child_span('llm.call', payload)
              when 'langgraph.checkpoint'
                child_span('checkpoint', payload)
              when 'langgraph.edge.taken'
                add_event(payload)
              end
            end
          end

          private

          def default_tracer_provider
            ::OpenTelemetry.tracer_provider
          end

          def root_span(payload)
            span = @tracer.start_span('graph.run')
            @run_spans[payload[:run_id]] = span
            span.add_attributes(filter_times(payload))
            span.finish
            @run_spans.delete(payload[:run_id])
          end

          def child_span(name, payload)
            parent = @run_spans[payload[:run_id]]
            return unless parent
            span = @tracer.start_span(name, with_parent: parent.context)
            span.add_attributes(filter_times(payload))
            span.finish
          end

          def add_event(payload)
            parent = @run_spans[payload[:run_id]]
            parent&.add_event('edge.taken', attributes: payload)
          end

          def filter_times(payload)
            payload.reject { |k, _| k.to_s.end_with?('at') || k.to_s.end_with?('ms') }
                   .transform_keys(&:to_s)
          end
        end
      end
    end
  end
end
