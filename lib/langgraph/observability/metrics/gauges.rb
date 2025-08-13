require_relative 'registry'

module Langgraph
  module Observability
    module Metrics
      module Gauges
        def self.set(name, value, labels = {})
          Registry.instance.set(name, value, labels)
        end
      end
    end
  end
end
