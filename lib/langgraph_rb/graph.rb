require 'set'
require 'securerandom'

module LangGraphRB
  class Graph
    START = :__start__
    FINISH = :__end__

    attr_reader :nodes, :edges, :state_class, :compiled

    def initialize(state_class: State, &dsl_block)
      @nodes = {}
      @edges = []
      @state_class = state_class
      @compiled = false
      
      # Built-in START and FINISH nodes
      @nodes[START] = Node.new(START) { |state| state }
      @nodes[FINISH] = Node.new(FINISH) { |state| state }

      instance_eval(&dsl_block) if dsl_block
    end

    # DSL Methods for building the graph
    def node(name, callable = nil, **options, &block)
      name = name.to_sym
      raise GraphError, "Node '#{name}' already exists" if @nodes.key?(name)
      
      if callable.respond_to?(:call)
        @nodes[name] = Node.new(name, callable)
      elsif block
        @nodes[name] = Node.new(name, &block)
      else
        raise GraphError, "Node '#{name}' must have a callable or block"
      end
    end

    def llm_node(name, llm_client:, system_prompt: nil, &block)
      name = name.to_sym
      raise GraphError, "Node '#{name}' already exists" if @nodes.key?(name)
      
      @nodes[name] = LLMNode.new(name, llm_client: llm_client, system_prompt: system_prompt, &block)
    end

    def tool_node(name, tools:, &block)
      name = name.to_sym
      raise GraphError, "Node '#{name}' already exists" if @nodes.key?(name)
      
      @nodes[name] = ToolNode.new(name, tools: tools, &block)
    end

    def edge(from, to)
      from, to = from.to_sym, to.to_sym
      validate_node_exists!(from)
      validate_node_exists!(to)
      
      @edges << Edge.new(from, to)
    end

    def conditional_edge(from, router, path_map = nil)
      from = from.to_sym
      validate_node_exists!(from)
      
      @edges << ConditionalEdge.new(from, router, path_map)
    end

    def fan_out_edge(from, destinations)
      from = from.to_sym
      validate_node_exists!(from)
      destinations = destinations.map(&:to_sym)
      
      destinations.each { |dest| validate_node_exists!(dest) }
      
      @edges << FanOutEdge.new(from, destinations)
    end

    # Set the entry point (typically from START)
    def set_entry_point(node_name)
      edge(START, node_name)
    end

    # Set exit point (typically to FINISH)
    def set_finish_point(node_name)
      edge(node_name, FINISH)
    end

    # Compile the graph (validate and prepare for execution)
    def compile!
      validate_graph!
      @compiled = true
      self
    end

    def compiled?
      @compiled
    end

    # Execute the graph synchronously
    def invoke(input_state = {}, context: nil, store: nil, thread_id: nil, observers: [])
      raise GraphError, "Graph must be compiled before execution" unless compiled?
      
      store ||= Stores::InMemoryStore.new
      thread_id ||= SecureRandom.hex(8)
      
      initial_state = @state_class.new(input_state)
      
      Runner.new(self, store: store, thread_id: thread_id, observers: observers)
        .invoke(initial_state, context: context)
    end

    # Stream execution results
    def stream(input_state = {}, context: nil, store: nil, thread_id: nil, observers: [])
      raise GraphError, "Graph must be compiled before execution" unless compiled?
      
      store ||= Stores::InMemoryStore.new
      thread_id ||= SecureRandom.hex(8)
      
      initial_state = @state_class.new(input_state)
      
      Runner.new(self, store: store, thread_id: thread_id, observers: observers)
        .stream(initial_state, context: context)
    end

    # Resume execution from a checkpoint
    def resume(thread_id, input_state = {}, context: nil, store: nil)
      raise GraphError, "Graph must be compiled before execution" unless compiled?
      raise GraphError, "Store required for resuming execution" unless store
      
      Runner.new(self, store: store, thread_id: thread_id).resume(input_state, context: context)
    end

    # Generate Mermaid diagram
    def to_mermaid
      lines = ["graph TD"]
      
      # Add nodes
      @nodes.each do |name, node|
        next if [START, FINISH].include?(name)
        lines << "    #{name}[\"#{name}\"]"
      end
      
      # Add special nodes
      lines << "    #{START}((START))"
      lines << "    #{FINISH}((FINISH))"
      
      # Add edges
      @edges.each do |edge|
        case edge
        when Edge
          lines << "    #{edge.from} --> #{edge.to}"
        when ConditionalEdge
          decision_name = "#{edge.from}_decision"
          # Connect source to decision node with a label
          lines << "    #{edge.from} -- condition --> #{decision_name}{\"condition\"}"
          # Add labeled branches from decision to each mapped destination
          if edge.path_map && !edge.path_map.empty?
            edge.path_map.each do |label, destination|
              lines << "    #{decision_name} -- #{label} --> #{destination}"
            end
          end
        when FanOutEdge
          edge.destinations.each do |dest|
            lines << "    #{edge.from} --> #{dest}"
          end
        end
      end
      
      lines.join("\n")
    end

    # Print Mermaid diagram
    def draw_mermaid
      puts to_mermaid
    end

    # Get all possible next nodes from a given node
    def get_next_nodes(from_node)
      from_node = from_node.to_sym
      next_nodes = []
      
      @edges.each do |edge|
        if edge.from == from_node
          case edge
          when Edge
            next_nodes << edge.to
          when ConditionalEdge, FanOutEdge
            # These require runtime evaluation
            next_nodes << :conditional
          end
        end
      end
      
      next_nodes.uniq
    end

    # Get all edges from a specific node
    def get_edges_from(node_name)
      node_name = node_name.to_sym
      @edges.select { |edge| edge.from == node_name }
    end

    private

    def validate_graph!
      # Check that START has outgoing edges
      start_edges = @edges.select { |e| e.from == START }
      raise GraphError, "No entry point defined (START node has no outgoing edges)" if start_edges.empty?
      
      # Check that all edge targets exist as nodes
      @edges.each do |edge|
        case edge
        when Edge
          validate_node_exists!(edge.from)
          validate_node_exists!(edge.to)
        when ConditionalEdge
          validate_node_exists!(edge.from)
          # Path map targets will be validated at runtime
        when FanOutEdge
          validate_node_exists!(edge.from)
          edge.destinations.each { |dest| validate_node_exists!(dest) }
        end
      end
      
      # Check for orphaned nodes (nodes with no incoming edges except START)
      nodes_with_incoming = @edges.flat_map do |edge|
        case edge
        when Edge
          [edge.to]
        when FanOutEdge
          edge.destinations
        else
          []
        end
      end.uniq
      
      orphaned = @nodes.keys - nodes_with_incoming - [START]
      unless orphaned.empty?
        puts "Warning: Orphaned nodes detected: #{orphaned.inspect}"
      end
      
      # Verify at least one path leads to FINISH
      reachable = find_reachable_nodes(START)
      unless reachable.include?(FINISH)
        puts "Warning: No path from START to FINISH found"
      end
    end

    def validate_node_exists!(node_name)
      node_name = node_name.to_sym
      unless @nodes.key?(node_name)
        raise GraphError, "Node '#{node_name}' does not exist"
      end
    end

    def find_reachable_nodes(start_node, visited = Set.new)
      return [] if visited.include?(start_node)
      
      visited.add(start_node)
      reachable = [start_node]
      
      edges_from_node = @edges.select { |e| e.from == start_node }
      
      edges_from_node.each do |edge|
        case edge
        when Edge
          reachable += find_reachable_nodes(edge.to, visited.dup)
        when FanOutEdge
          edge.destinations.each do |dest|
            reachable += find_reachable_nodes(dest, visited.dup)
          end
        # ConditionalEdge paths are dynamic, so we can't pre-validate them
        end
      end
      
      reachable.uniq
    end
  end
end 