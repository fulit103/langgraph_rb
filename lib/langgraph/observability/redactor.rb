module Langgraph
  module Observability
    class Redactor
      DEFAULT_PATTERNS = [
        /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i,
        /\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/,
        /\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b/
      ].freeze

      def initialize(custom_patterns: [])
        @patterns = DEFAULT_PATTERNS + Array(custom_patterns)
      end

      def redact_string(str)
        return str unless str.is_a?(String)
        @patterns.each { |p| str = str.gsub(p, '[REDACTED]') }
        str
      end

      def redact_hash(hash)
        hash.transform_values do |v|
          case v
          when String then redact_string(v)
          when Hash then redact_hash(v)
          else v
          end
        end
      end
    end
  end
end
