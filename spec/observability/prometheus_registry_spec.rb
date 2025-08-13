require 'spec_helper'

RSpec.describe Langgraph::Observability::Adapters::Prometheus do
  it 'collects metrics from notifications' do
    described_class.enable!
    start = Time.now
    finish = start + 1
    payload = { graph_name: 'g', graph_version: '1', env: 'test', run_id: 'r1', started_at: start, finished_at: finish, status: 'ok' }
    Langgraph::Observability::Notifications.instrument('langgraph.graph.run', payload)
    registry = Langgraph::Observability::Metrics::Registry.instance
    counter = registry.counters['langgraph_graph_run_total'][{ graph_name: 'g', status: 'ok' }]
    expect(counter).to eq(1)
    hist = registry.histograms['langgraph_graph_run_duration_ms'][{ graph_name: 'g', graph_version: '1', env: 'test', status: 'ok' }]
    expect(hist.first).to be_within(0.1).of(1000.0)
  end
end
