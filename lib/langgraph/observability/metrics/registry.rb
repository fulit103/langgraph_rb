require 'singleton'

module Langgraph
  module Observability
    module Metrics
      class Registry
        include Singleton
        attr_reader :counters, :histograms, :gauges

        def initialize
          @counters = Hash.new { |h, k| h[k] = Hash.new(0) }
          @histograms = Hash.new { |h, k| h[k] = Hash.new { |hh, kk| hh[kk] = [] } }
          @gauges = Hash.new { |h, k| h[k] = Hash.new } 
          @mutex = Mutex.new
        end

        def increment(name, labels = {}, value = 1)
          @mutex.synchronize { @counters[name][labels] += value }
        end

        def observe(name, value, labels = {})
          @mutex.synchronize { @histograms[name][labels] << value }
        end

        def set(name, value, labels = {})
          @mutex.synchronize { @gauges[name][labels] = value }
        end
      end
    end
  end
end
