require 'ostruct'

module Langgraph
  module Observability
    class Config
      attr_accessor :env, :service_name, :trace_sample_rate,
                    :redaction, :logging, :metrics, :prometheus, :otel

      def initialize
        @env = ENV['RACK_ENV'] || 'development'
        @service_name = 'langgraph'
        @trace_sample_rate = 0.1
        @redaction = OpenStruct.new(enabled: true, custom_patterns: [])
        @logging = OpenStruct.new(json: true)
        @metrics = OpenStruct.new(backend: :otel)
        @prometheus = OpenStruct.new(default_labels: { service: 'langgraph' })
        @otel = OpenStruct.new(exporter: :otlp, resource: { 'service.name' => 'langgraph' })
      end
    end

    class << self
      attr_accessor :config

      def configure
        self.config ||= Config.new
        yield(config) if block_given?
      end
    end
  end
end
