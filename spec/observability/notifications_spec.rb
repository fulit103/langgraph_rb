require 'spec_helper'

RSpec.describe Langgraph::Observability::Notifications do
  it 'emits events with payload' do
    received = nil
    described_class.subscribe('langgraph.graph.run') { |e| received = e.payload }
    payload = { graph_name: 'g', graph_version: '1', run_id: 'r1', thread_id: 1, env: 'test', started_at: Time.now, finished_at: Time.now, status: 'ok' }
    described_class.instrument('langgraph.graph.run', payload)
    expect(received).to eq(payload)
  end
end
