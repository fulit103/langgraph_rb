module Langgraph
  module Observability
    module Adapters
      module Rails
        def self.install
          # In real implementation, hook into Rails boot process.
          true
        end
      end
    end
  end
end
