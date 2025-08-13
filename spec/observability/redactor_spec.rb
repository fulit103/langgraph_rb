require 'spec_helper'

RSpec.describe Langgraph::Observability::Redactor do
  it 'redacts pii in strings' do
    r = described_class.new
    expect(r.redact_string('contact me at test@example.com')).to eq('contact me at [REDACTED]')
  end

  it 'redacts in hashes' do
    r = described_class.new
    result = r.redact_hash({ email: 'user@test.com', nested: { phone: '123-456-7890' } })
    expect(result[:email]).to eq('[REDACTED]')
    expect(result[:nested][:phone]).to eq('[REDACTED]')
  end
end
