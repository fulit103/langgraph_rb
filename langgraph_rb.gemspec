require_relative 'lib/langgraph_rb/version'

Gem::Specification.new do |spec|
  spec.name          = "langgraph_rb"
  spec.version       = LangGraphRB::VERSION
  spec.authors       = ["Julian Toro"]
  spec.email         = ["fulit103@gmail.com"]

  spec.summary       = "A Ruby library for building stateful, multi-actor applications with directed graphs"
  spec.description   = <<~DESC
    LangGraphRB is a Ruby library inspired by LangGraph for building stateful, multi-actor applications 
    using directed graphs. It provides a framework for orchestrating complex workflows with support for 
    parallel execution, checkpointing, human-in-the-loop interactions, and map-reduce operations.
  DESC
  spec.homepage      = "https://github.com/fulit103/langgraph_rb"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{\A(?:test|spec|features)/})
    end
  end
  
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "json", "~> 2.0"
  spec.add_dependency "openai", "~> 0.24.0"

  # Development dependencies
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry", "~> 0.14"
  spec.add_development_dependency "rubocop", "~> 1.0"
end 