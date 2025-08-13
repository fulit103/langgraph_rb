require 'prometheus/client'
require_relative '../notifications'
require_relative '../metrics/registry'
require_relative '../metrics/counters'
require_relative '../metrics/histograms'
require_relative '../metrics/gauges'

module Langgraph
  module Observability
    module Adapters
      module Prometheus
        def self.enable!
          Notifications.subscribe do |event|
            payload = event.payload
            case event.name
            when 'langgraph.graph.run'
              Metrics::Counters.increment('langgraph_graph_run_total',
                { graph_name: payload[:graph_name], status: payload[:status] })
              duration = (payload[:finished_at] - payload[:started_at]) * 1000.0
              Metrics::Histograms.observe('langgraph_graph_run_duration_ms', duration,
                { graph_name: payload[:graph_name], graph_version: payload[:graph_version], env: payload[:env], status: payload[:status] })
            when 'langgraph.node.run'
              Metrics::Counters.increment('langgraph_node_run_total',
                { graph_name: payload[:graph_name], node_id: payload[:node_id], status: payload[:status] })
              duration = (payload[:finished_at] - payload[:started_at]) * 1000.0
              Metrics::Histograms.observe('langgraph_node_run_duration_ms', duration,
                { graph_name: payload[:graph_name], node_id: payload[:node_id], node_type: payload[:node_type], env: payload[:env], status: payload[:status] })
            when 'langgraph.llm.call'
              Metrics::Counters.increment('langgraph_llm_request_total',
                { graph_name: payload[:graph_name], provider: payload[:provider], model: payload[:model], status: payload[:status] })
              duration = payload[:duration_ms]
              Metrics::Histograms.observe('langgraph_llm_call_duration_ms', duration,
                { graph_name: payload[:graph_name], provider: payload[:provider], model: payload[:model], cached: payload[:cached], env: payload[:env], status: payload[:status] })
            end
          end
        end
      end
    end
  end
end
