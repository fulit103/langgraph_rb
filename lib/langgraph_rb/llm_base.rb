require 'json'

module LangGraphRB
  # Abstract base for chat LLM clients.
  # Implementations must provide #call(messages, tools: nil) and may support #bind_tools.
  class LLMBase
    attr_reader :model, :temperature

    def initialize(model:, temperature: 0.0)
      @model = model
      @temperature = temperature
      @bound_tools = []
      @observers = []
      @node_name = nil
    end

    # Called by runtime to allow LLM client to emit tracing/telemetry events
    def set_observers(observers, node_name)
      @observers = Array(observers)
      @node_name = node_name
    end

    def bind_tools(tools)
      @bound_tools = Array(tools)
      self
    end

    def bound_tools
      @bound_tools
    end

    def call(_messages, tools: nil)
      raise NotImplementedError, "Subclasses must implement #call(messages, tools: nil)"
    end

    protected

    def notify_llm_request(payload)
      @observers.each do |observer|
        begin
          observer.on_llm_request(payload, @node_name)
        rescue => _e
          # Ignore observer errors
        end
      end
    end

    def notify_llm_response(payload)
      @observers.each do |observer|
        begin
          observer.on_llm_response(payload, @node_name)
        rescue => _e
          # Ignore observer errors
        end
      end
    end

    def notify_llm_error(payload)
      @observers.each do |observer|
        begin
          observer.on_llm_error(payload, @node_name)
        rescue => _e
          # Ignore observer errors
        end
      end
    end
  end
end


