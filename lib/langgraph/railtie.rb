begin
  require 'rails/railtie'
rescue LoadError
end
require_relative 'observability/adapters/rails'

module Langgraph
  class Railtie < ::Rails::Railtie
    initializer 'langgraph.observability' do
      Observability::Adapters::Rails.install
    end
  end
end if defined?(Rails)
