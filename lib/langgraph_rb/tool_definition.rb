require 'json'

module LangGraphRB
  # Mixin to declare tool functions compatible with OpenAI tool/function calling
  module ToolDefinition
    def self.extended(base)
      base.instance_variable_set(:@__tool_functions, {})
    end

    def define_function(name, description: "", &block)
      fn_name = name.to_sym
      @__tool_functions ||= {}
      @__tool_functions[fn_name] = {
        name: fn_name,
        description: description,
        parameters: { type: 'object', properties: {}, required: [] }
      }

      # Evaluate the DSL inside a builder to collect properties
      if block
        builder = FunctionSchemaBuilder.new(@__tool_functions[fn_name][:parameters])
        builder.instance_eval(&block)
      end
    end

    def tool_functions
      @__tool_functions || {}
    end

    def to_openai_tool_schema
      # One class may expose multiple functions; return an array of tool entries
      tool_functions.values.map do |fn|
        {
          type: 'function',
          function: {
            name: fn[:name].to_s,
            description: fn[:description],
            parameters: fn[:parameters]
          }
        }
      end
    end

    class FunctionSchemaBuilder
      def initialize(parameters)
        @parameters = parameters
      end

      def property(name, type:, description: "", required: false)
        @parameters[:properties][name.to_sym] = { type: type, description: description }
        if required
          @parameters[:required] ||= []
          @parameters[:required] << name.to_sym
        end
      end
    end
  end

  # Base class for tools using the ToolDefinition mixin
  class ToolBase
    extend ToolDefinition

    def call(call_args)
      # call_args: { name:, arguments: {} } or OpenAI-like hash
      name = call_args[:name] || call_args['name']
      args = call_args[:arguments] || call_args['arguments'] || {}
      raise ArgumentError, 'Tool call missing name' if name.nil?

      method_name = name.to_sym
      unless respond_to?(method_name)
        raise ArgumentError, "Undefined tool function: #{name}"
      end

      result = public_send(method_name, **symbolize_keys(args))
      tool_response(result)
    end

    # Standardize tool responses; can be overridden by subclasses
    def tool_response(payload)
      payload
    end

    def to_openai_tool_schema
      self.class.to_openai_tool_schema
    end

    private

    def symbolize_keys(hash)
      return hash unless hash.is_a?(Hash)
      hash.transform_keys { |k| k.respond_to?(:to_sym) ? k.to_sym : k }
    end
  end
end


