require 'rspec'
require_relative '../lib/langgraph/observability/config'
require_relative '../lib/langgraph/observability/notifications'
require_relative '../lib/langgraph/observability/redactor'
require_relative '../lib/langgraph/observability/json_logger'
require_relative '../lib/langgraph/observability/adapters/prometheus'
require_relative '../lib/langgraph/observability/adapters/opentelemetry'
require_relative '../lib/langgraph/observability/adapters/rails'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
