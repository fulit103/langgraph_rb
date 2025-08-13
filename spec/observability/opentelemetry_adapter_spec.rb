require 'spec_helper'
require 'opentelemetry/sdk'

RSpec.describe Langgraph::Observability::Adapters::OpenTelemetry do
  it 'creates spans for graph run' do
    exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    span_processor = OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter)
    provider = OpenTelemetry::SDK::Trace::TracerProvider.new
    provider.add_span_processor(span_processor)
    described_class.subscribe!(tracer_provider: provider)
    start = Time.now
    finish = start + 1
    payload = { graph_name: 'g', graph_version: '1', run_id: 'r1', env: 'test', started_at: start, finished_at: finish, status: 'ok' }
    Langgraph::Observability::Notifications.instrument('langgraph.graph.run', payload)
    span = exporter.finished_spans.first
    expect(span.name).to eq('graph.run')
    expect(span.attributes['graph_name']).to eq('g')
  end
end
