module LangGraphRB
  # Command combines a state update with a routing decision
  class Command
    attr_reader :update, :goto

    def initialize(update: nil, goto: nil)
      @update = update || {}
      @goto = goto
    end

    def self.update(state_delta)
      new(update: state_delta)
    end

    def self.goto(destination)
      new(goto: destination)
    end

    def self.update_and_goto(state_delta, destination)
      new(update: state_delta, goto: destination)
    end

    def to_s
      parts = []
      parts << "update: #{@update.inspect}" unless @update.empty?
      parts << "goto: #{@goto}" if @goto
      "#<Command #{parts.join(', ')}>"
    end

    def inspect
      to_s
    end
  end

  # Send creates a new parallel execution branch with specific payload
  class Send
    attr_reader :to, :payload

    def initialize(to:, payload: {})
      @to = to.to_sym
      @payload = payload || {}
    end

    def to_s
      "#<Send to: #{@to}, payload: #{@payload.inspect}>"
    end

    def inspect
      to_s
    end
  end

  # MultiSend creates multiple parallel execution branches
  class MultiSend
    attr_reader :sends

    def initialize(*sends)
      @sends = sends.flatten
    end

    def self.to_multiple(destinations, payload = {})
      sends = destinations.map { |dest| Send.new(to: dest, payload: payload) }
      new(sends)
    end

    def self.fan_out(node, payloads)
      sends = payloads.map { |payload| Send.new(to: node, payload: payload) }
      new(sends)
    end

    def to_s
      "#<MultiSend #{@sends.map(&:to_s).join(', ')}>"
    end

    def inspect
      to_s
    end
  end

  # Interrupt execution and wait for human input
  class Interrupt
    attr_reader :message, :data

    def initialize(message: "Human input required", data: {})
      @message = message
      @data = data
    end

    def to_s
      "#<Interrupt: #{@message}>"
    end

    def inspect
      to_s
    end
  end

  # Helper module for creating commands
  module Commands
    def self.update(state_delta)
      Command.update(state_delta)
    end

    def self.goto(destination)
      Command.goto(destination)
    end

    def self.update_and_goto(state_delta, destination)
      Command.update_and_goto(state_delta, destination)
    end

    def self.send_to(destination, payload = {})
      Send.new(to: destination, payload: payload)
    end

    def self.send_to_multiple(destinations, payload = {})
      MultiSend.to_multiple(destinations, payload)
    end

    def self.fan_out(node, payloads)
      MultiSend.fan_out(node, payloads)
    end

    def self.interrupt(message: "Human input required", data: {})
      Interrupt.new(message: message, data: data)
    end

    def self.end_execution(final_state = {})
      Command.update_and_goto(final_state, Graph::FINISH)
    end
  end
end 