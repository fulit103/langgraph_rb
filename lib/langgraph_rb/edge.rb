module LangGraphRB
  # Simple edge connecting two nodes
  class Edge
    attr_reader :from, :to

    def initialize(from, to)
      @from = from.to_sym
      @to = to.to_sym
    end

    def route(state, context: nil)
      [@to]
    end

    def to_s
      "#{@from} -> #{@to}"
    end

    def inspect
      "#<Edge: #{to_s}>"
    end

    def ==(other)
      other.is_a?(Edge) && @from == other.from && @to == other.to
    end
  end

  # Conditional edge that uses a router function to determine destination(s)
  class ConditionalEdge
    attr_reader :from, :router, :path_map

    def initialize(from, router, path_map = nil)
      @from = from.to_sym
      @router = router
      @path_map = path_map || {}
    end

    # Route based on the router function result
    def route(state, context: nil)
      result = case @router.arity
               when 0
                 @router.call
               when 1
                 @router.call(state)
               else
                 @router.call(state, context)
               end

      # Convert result to destinations
      destinations = case result
                    when Array
                      result
                    when String, Symbol
                      [result]
                    when Hash
                      # Support for multiple destinations with different states
                      result.keys
                    else
                      [result]
                    end

      # Map through path_map if provided
      destinations.map do |dest|
        mapped = @path_map[dest.to_s] || @path_map[dest.to_sym] || dest
        mapped.to_sym
      end
    end

    def to_s
      "#{@from} -> [conditional]"
    end

    def inspect
      "#<ConditionalEdge: #{to_s}>"
    end
  end

  # Fan-out edge that creates multiple parallel executions
  class FanOutEdge
    attr_reader :from, :destinations

    def initialize(from, destinations)
      @from = from.to_sym
      @destinations = destinations.map(&:to_sym)
    end

    def route(state, context: nil)
      @destinations
    end

    def to_s
      "#{@from} -> #{@destinations.inspect}"
    end

    def inspect
      "#<FanOutEdge: #{to_s}>"
    end
  end

  # Helper class for building conditional routing
  class Router
    def self.build(&block)
      new.tap { |r| r.instance_eval(&block) }
    end

    def initialize
      @conditions = []
    end

    def when(condition, destination)
      @conditions << [condition, destination]
      self
    end

    def otherwise(destination)
      @default = destination
      self
    end

    def call(state, context = nil)
      @conditions.each do |condition, destination|
        result = case condition.arity
                when 0
                  condition.call
                when 1
                  condition.call(state)
                else
                  condition.call(state, context)
                end
        
        return destination if result
      end

      @default || raise("No matching condition and no default specified")
    end

    def to_proc
      method(:call).to_proc
    end
  end
end 