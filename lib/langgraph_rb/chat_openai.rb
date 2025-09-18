require 'openai'
require_relative 'llm_base'

module LangGraphRB
  # ChatOpenAI wrapper compatible with LLMBase, supporting tool binding
  class ChatOpenAI < LLMBase
    def initialize(model:, temperature: 0.0, api_key: ENV['OPENAI_API_KEY'])
      super(model: model, temperature: temperature)
      @client = OpenAI::Client.new(api_key: api_key)
    end

    # Returns a new instance with tools bound (non-destructive)
    def bind_tools(tools)
      dup_instance = self.class.new(model: @model, temperature: @temperature)      
      dup_instance.instance_variable_set(:@client, @client)
      dup_instance.instance_variable_set(:@bound_tools, Array(tools))
      dup_instance
    end

    # messages: array of { role: 'system'|'user'|'assistant'|'tool', content: string, tool_calls?: [...] }
    # tools: optional array of tool definitions (objects responding to .to_openai_tool_schema)
    # Returns assistant text string or a tool-call envelope hash when tool calls are produced
    def call(messages, tools: nil)
      raise ArgumentError, 'messages must be an Array' unless messages.is_a?(Array)

      tool_definitions = (tools || @bound_tools)
      tool_schemas = Array(tool_definitions).flat_map do |tool|
        if tool.respond_to?(:to_openai_tool_schema)
          Array(tool.to_openai_tool_schema)
        else
          [tool]
        end
      end

      request_payload = {
        model: @model,
        temperature: @temperature,
        messages: normalize_messages(messages)
      }

      if tool_schemas && !tool_schemas.empty?
        request_payload[:tools] = tool_schemas
        request_payload[:tool_choice] = 'auto'
      end

      notify_llm_request({
        name: 'OpenAI::ChatCompletion',
        model: @model,
        model_parameters: { temperature: @temperature },
        input: request_payload[:messages]
      })

      # openai 0.24.0 uses client.chat.completions.create(params)
      response = @client.chat.completions.create(request_payload)

      message = extract_message_from_response(response)
      tool_calls = message[:tool_calls]
      text_content = message[:content] 

      usage = extract_usage_from_response(response)
      notify_llm_response({
        output: tool_calls ? { tool_calls: tool_calls } : text_content,
        prompt_tokens: usage[:prompt_tokens],
        completion_tokens: usage[:completion_tokens],
        total_tokens: usage[:total_tokens]
      })

      if tool_calls && !tool_calls.empty?
        normalized_calls = tool_calls.map do |tc|
          {
            id: tc[:id],
            name: tc[:function][:name],
            arguments: parse_tool_arguments(tc[:function][:arguments])
          }
        end
        { tool_calls: normalized_calls }
      else
        text_content
      end
    end

    private

    def normalize_messages(messages)
      messages.map do |m|
        role = (m[:role] || m['role'])
        content = m[:content] || m['content']

        normalized = { role: role }

        if content.is_a?(Array)
          normalized[:content] = content
        elsif content.nil?
          normalized[:content] = nil
        else
          normalized[:content] = content.to_s
        end

        # Preserve assistant tool_calls; convert internal format back to OpenAI shape
        tool_calls = m[:tool_calls] || m['tool_calls']
        if tool_calls && role.to_s == 'assistant'
          normalized[:tool_calls] = Array(tool_calls).map do |tc|
            # Already OpenAI shape
            if tc[:function] || tc['function']
              fn = tc[:function] || tc['function']
              raw_args = fn[:arguments] || fn['arguments']
              args_str = raw_args.is_a?(String) ? raw_args : JSON.dump(raw_args || {})
              {
                id: (tc[:id] || tc['id']),
                type: 'function',
                function: {
                  name: (fn[:name] || fn['name']).to_s,
                  arguments: args_str
                }
              }
            else
              # Internal normalized shape { id:, name:, arguments: Hash|String }
              raw_args = tc[:arguments] || tc['arguments']
              args_str = raw_args.is_a?(String) ? raw_args : JSON.dump(raw_args || {})
              {
                id: (tc[:id] || tc['id']),
                type: 'function',
                function: {
                  name: (tc[:name] || tc['name']).to_s,
                  arguments: args_str
                }
              }
            end
          end
        end

        # Preserve tool message linkage
        if role.to_s == 'tool'
          tool_call_id = m[:tool_call_id] || m['tool_call_id']
          name = m[:name] || m['name']
          normalized[:tool_call_id] = tool_call_id if tool_call_id
          normalized[:name] = name if name
        end

        normalized
      end
    end

    def parse_tool_arguments(raw)
      return {} if raw.nil?
      case raw
      when String
        JSON.parse(raw) rescue {}
      when Hash
        raw
      else
        {}
      end
    end

    def extract_message_from_response(response)
      # Handles both Hash responses and typed OpenAI::Models::* objects
      if response.respond_to?(:choices)
        first_choice = response.choices.first
        if first_choice.respond_to?(:[])
          first_choice[:message] || first_choice['message'] || {}
        else
          # In some versions, choices elements are structs with #message
          first_choice.message
        end
      else
        (response['choices'] || []).dig(0, 'message') || {}
      end
    end

    def extract_usage_from_response(response)
      usage = if response.respond_to?(:usage)
        response.usage
      else
        response['usage']
      end

      return { prompt_tokens: nil, completion_tokens: nil, total_tokens: nil } unless usage

      if usage.respond_to?(:[]) || usage.is_a?(Hash)
        {
          prompt_tokens: usage[:prompt_tokens] || usage['prompt_tokens'],
          completion_tokens: usage[:completion_tokens] || usage['completion_tokens'],
          total_tokens: usage[:total_tokens] || usage['total_tokens']
        }
      else
        {
          prompt_tokens: usage.prompt_tokens,
          completion_tokens: usage.completion_tokens,
          total_tokens: usage.total_tokens
        }
      end
    end
  end
end


