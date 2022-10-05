# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "gitlab_graph/gem_version"

Gem::Specification.new do |spec|
  spec.name                  = "danger-gitlab_graph"
  spec.version               = GitlabGraph::VERSION
  spec.authors               = ["Jan Beckmann"]
  spec.email                 = ["king-jan1999@hotmail.de"]
  spec.description           = "Danger plugin for creating graph from ci metrics."
  spec.summary               = "Danger plugin which allows you to extract and visualize metrics over previous ci runs."
  spec.homepage              = "https://github.com/kingjan1999/danger-gitlab_graph"
  spec.license               = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.add_runtime_dependency "danger-plugin-api", "~> 1.0"
  spec.add_runtime_dependency "svg-graph", "~> 2.2.1"

  # General ruby development
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"

  # Testing support
  spec.add_development_dependency "rspec", "~> 3.4"

  # Linting code and docs
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "yard"

  # Makes testing easy via `bundle exec guard`
  spec.add_development_dependency "guard", "~> 2.14"
  spec.add_development_dependency "guard-rspec", "~> 4.7"

  # If you want to work on older builds of ruby
  spec.add_development_dependency "listen", "3.0.7"

  # This gives you the chance to run a REPL inside your tests
  # via:
  #
  #    require 'pry'
  #    binding.pry
  #
  # This will stop test execution and let you inspect the results
  spec.add_development_dependency "pry"

  spec.add_development_dependency "danger-gitlab"
  spec.add_development_dependency "webmock", "~> 2.1"
end
