require 'spec_helper'

RSpec.describe Langgraph::Observability::Adapters::Rails do
  it 'installs without error' do
    expect { described_class.install }.not_to raise_error
  end
end
