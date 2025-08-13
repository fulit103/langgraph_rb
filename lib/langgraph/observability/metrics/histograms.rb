require_relative 'registry'

module Langgraph
  module Observability
    module Metrics
      module Histograms
        def self.observe(name, value, labels = {})
          Registry.instance.observe(name, value, labels)
        end
      end
    end
  end
end
