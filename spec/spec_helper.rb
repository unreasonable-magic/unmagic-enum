# frozen_string_literal: true

require "bundler/setup"
require "unmagic-enum"

# Conditionally require ActiveRecord for testing integration
begin
  require "active_record"
  require "active_support/all"
rescue LoadError
  puts "⚠️  ActiveRecord not available - skipping ActiveRecord integration tests"
  require "active_support"
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true

  if config.files_to_run.one?
    config.default_formatter = "doc"
  end

  config.order = :random
  Kernel.srand config.seed

  # Skip ActiveRecord tests if ActiveRecord is not available
  unless defined?(ActiveRecord)
    config.filter_run_excluding :activerecord
  end
end