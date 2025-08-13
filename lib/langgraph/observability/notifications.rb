require 'active_support'

module Langgraph
  module Observability
    module Notifications
      EVENTS = %w[
        langgraph.graph.run
        langgraph.node.run
        langgraph.edge.taken
        langgraph.llm.call
        langgraph.checkpoint
      ].freeze

      def self.instrument(event, payload = {})
        raise ArgumentError, 'unknown event' unless EVENTS.include?(event)
        ActiveSupport::Notifications.instrument(event, payload)
      end

      def self.subscribe(pattern = /^langgraph\./)
        ActiveSupport::Notifications.subscribe(pattern) do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          yield(event) if block_given?
        end
      end
    end
  end
end
