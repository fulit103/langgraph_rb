module LangGraphRB
  class State < Hash
    attr_reader :reducers

    def initialize(schema = {}, reducers = {})
      @reducers = reducers || {}
      super()
      merge!(schema) if schema.is_a?(Hash)
    end

    # Merge a delta (partial state update) using reducers
    def merge_delta(delta)
      return self if delta.nil? || delta.empty?
      
      new_state = self.class.new({}, @reducers)
      new_state.merge!(self)
      
      delta.each do |key, value|
        key = key.to_sym
        
        if @reducers[key]
          # Use the reducer function to combine old and new values
          new_state[key] = @reducers[key].call(self[key], value)
        else
          # Simple replacement
          new_state[key] = value
        end
      end
      
      new_state
    end

    # Create a new state with additional reducers
    def with_reducers(new_reducers)
      self.class.new(self, @reducers.merge(new_reducers))
    end

    # Common reducer for adding messages to an array
    def self.add_messages
      ->(old_value, new_value) do
        old_array = old_value || []
        new_array = new_value.is_a?(Array) ? new_value : [new_value]
        old_array + new_array
      end
    end

    # Common reducer for appending strings
    def self.append_string
      ->(old_value, new_value) do
        (old_value || "") + new_value.to_s
      end
    end

    # Common reducer for merging hashes
    def self.merge_hash
      ->(old_value, new_value) do
        old_hash = old_value || {}
        old_hash.merge(new_value || {})
      end
    end

    def to_h
      Hash[self]
    end

    def inspect
      "#<#{self.class.name} #{super}>"
    end
  end
end 