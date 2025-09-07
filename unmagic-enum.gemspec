# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name        = "unmagic-enum"
  spec.version     = "0.1.0"
  spec.authors     = ["Unmagic"]
  spec.email       = ["hello@unmagic.ai"]
  spec.summary     = "Type-safe enums with attributes for Rails applications"
  spec.description = "A powerful enum system providing type-safe enumerations with custom attributes, STI integration, and ActiveRecord support"
  spec.homepage    = "https://unmagic.ai"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/CHANGELOG.md"

  spec.files = Dir["lib/**/*", "README.md", "LICENSE", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.0"
  
  spec.add_dependency "activesupport", ">= 7.0.0"
  
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rake", "~> 13.0"
end