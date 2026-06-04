# frozen_string_literal: true

require_relative "lib/unmagic/enum/version"

Gem::Specification.new do |spec|
  spec.name        = "unmagic-enum"
  spec.version     = Unmagic::Enum::VERSION
  spec.authors     = ["Keith Pitt"]
  spec.email       = ["keith@unreasonable-magic.com"]
  spec.summary     = "Type-safe enums with attributes for Rails applications"
  spec.description = "A powerful enum system providing type-safe enumerations with custom attributes, STI integration, and ActiveRecord support"
  spec.homepage    = "https://github.com/unreasonable-magic/unmagic-enum"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir["lib/**/*", "README.md", "LICENSE", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.0"

  spec.add_dependency "activesupport", "~> 7.0", ">= 7.0.0"

  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rake", "~> 13.0"
end
