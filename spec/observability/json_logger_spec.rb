require 'spec_helper'
require 'stringio'

RSpec.describe Langgraph::Observability::JsonLogger do
  it 'writes redacted json' do
    io = StringIO.new
    logger = described_class.new(io)
    Thread.current[:langgraph_run_id] = 'run-1'
    logger.info('user email test@example.com')
    output = JSON.parse(io.string)
    expect(output['run_id']).to eq('run-1')
    expect(output['message']).to include('[REDACTED]')
  end
end
