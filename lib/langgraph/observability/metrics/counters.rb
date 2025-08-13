require_relative 'registry'

module Langgraph
  module Observability
    module Metrics
      module Counters
        def self.increment(name, labels = {}, value = 1)
          Registry.instance.increment(name, labels, value)
        end
      end
    end
  end
end
