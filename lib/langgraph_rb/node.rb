module LangGraphRB
  class Node
    attr_reader :name, :block

    def initialize(name, callable = nil, &block)
      @name = name.to_sym
      @callable = callable || block
      
      raise NodeError, "Node '#{name}' must have a callable or block" unless @callable
    end

    # Execute the node with the given state and context
    # Returns either a Hash (state delta), Command, or Send object
    def call(state, context: nil)
      case @callable.arity
      when 0
        @callable.call
      when 1
        @callable.call(state)
      else
        @callable.call(state, context)
      end
    rescue => e
      raise NodeError, "Error executing node '#{@name}': #{e.message}"
    end

    def to_s
      "#<Node:#{@name}>"
    end

    def inspect
      to_s
    end
  end

  # Specialized node for LLM calls
  class LLMNode < Node
    attr_reader :llm_client, :system_prompt

    def initialize(name, llm_client:, system_prompt: nil, &block)
      @llm_client = llm_client
      @system_prompt = system_prompt
      
      super(name, &block)
    end

    def call(state, context: nil)
      # If no custom block provided, use default LLM behavior
      if @callable.nil? || @callable == method(:default_llm_call)
        default_llm_call(state, context)
      else
        super(state, context: context)
      end
    end

    private

    def default_llm_call(state, context)
      messages = state[:messages] || []
      messages = [@system_prompt] + messages if @system_prompt && !messages.empty?
      
      response = @llm_client.call(messages)
      
      {
        messages: [{ role: 'assistant', content: response }],
        last_response: response
      }
    end
  end

  # Specialized node for tool calls
  class ToolNode < Node
    attr_reader :tool

    def initialize(name, tool:, &block)
      @tool = tool
      super(name, &(block || method(:default_tool_call)))
    end

    private

    def default_tool_call(state, context)
      # Extract tool call from last message or state
      tool_call = state[:tool_call] || extract_tool_call_from_messages(state[:messages])
      
      return { error: "No tool call found" } unless tool_call

      result = @tool.call(tool_call[:args])
      
      {
        messages: [{
          role: 'tool',
          content: result.to_s,
          tool_call_id: tool_call[:id]
        }],
        tool_result: result
      }
    end

    def extract_tool_call_from_messages(messages)
      return nil unless messages

      messages.reverse.each do |msg|
        if msg[:tool_calls]
          return msg[:tool_calls].first
        end
      end
      
      nil
    end
  end
end 