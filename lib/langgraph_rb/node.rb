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
    def call(state, context: nil, observers: [])
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

      # Use default LLM behavior if no custom block provided
      super(name, &(block || method(:default_llm_call)))
    end

    def call(state, context: nil, observers: [])
      # Auto-inject LLM config into the context for both default and custom blocks
      merged_context = (context || {}).merge(
        llm_client: @llm_client,
        system_prompt: @system_prompt
      )

      begin
        @llm_client&.set_observers(observers, @name) if observers.any?
      rescue => e
        raise NodeError, "Error setting observers for LLM client: #{e.message}"
      end

      # Delegate to Node's dispatcher so arity (0/1/2) is handled uniformly
      case @callable.arity
      when 0
        @callable.call
      when 1
        @callable.call(state)
      else
        @callable.call(state, merged_context)
      end
    rescue => e
      raise NodeError, "Error executing node '#{@name}': #{e.message}"
    end

    private

    def default_llm_call(state, context)
      messages = state[:messages] || []
      if context && context[:system_prompt]
        messages = [{ role: 'system', content: context[:system_prompt] }] + messages
      end

      response = (context[:llm_client] || @llm_client).call(messages)

      if response.is_a?(Hash) && response[:tool_calls]
        assistant_msg = {
          role: 'assistant',
          content: nil,
          tool_calls: response[:tool_calls]
        }
        {
          messages: (state[:messages] || []) + [assistant_msg],
          tool_call: response[:tool_calls].first
        }
      else
        assistant_msg = { role: 'assistant', content: response.to_s }
        {
          messages: (state[:messages] || []) + [assistant_msg],
          last_response: response.to_s
        }
      end
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

      # Normalize expected structure for tool dispatch
      normalized = normalize_tool_call(tool_call)
      result = @tool.call(normalized)
      
      tool_message = {
        role: 'tool',
        content: result.to_s,
        tool_call_id: normalized[:id],
        name: normalized[:name]
      }

      {
        messages: (state[:messages] || []) + [tool_message],
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

    def normalize_tool_call(call)
      # Supports shapes from OpenAI and our internal format
      if call.is_a?(Hash)
        if call[:name] && call[:arguments]
          return {
            id: call[:id],
            name: call[:name].to_sym,
            arguments: call[:arguments]
          }
        elsif call[:function]
          return {
            id: call[:id],
            name: (call.dig(:function, :name) || call.dig('function', 'name')).to_sym,
            arguments: call.dig(:function, :arguments) || call.dig('function', 'arguments')
          }
        elsif call[:args]
          return {
            id: call[:id],
            name: (call[:name] || call['name']).to_sym,
            arguments: call[:args]
          }
        end
      end
      call
    end
  end
end 