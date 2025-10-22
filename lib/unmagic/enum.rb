# frozen_string_literal: true

require 'set'

module Unmagic
  # Base class for creating type-safe enums with string values
  #
  # Basic usage:
  #   class Status < Unmagic::Enum
  #     ACTIVE = new("active")
  #     PENDING = new("pending")
  #     ARCHIVED = new("archived")
  #   end
  #
  # With attributes:
  #   class Priority < Unmagic::Enum
  #     attribute :label
  #     attribute :color
  #
  #     HIGH = new("high", label: "High Priority", color: "red")
  #     MEDIUM = new("medium", label: "Medium Priority", color: "yellow")
  #     LOW = new("low", label: "Low Priority", color: "green")
  #   end
  #
  # Key/Value separation (useful for database migrations):
  #   class MessageType < Unmagic::Enum
  #     # The key is what you use in code, value is what's stored in DB
  #     USER = new("user")                           # key and value both "user"
  #     ENTITY = new("entity", value: "bot")         # key: "entity", value: "bot" (legacy DB)
  #     SYSTEM = new("system", value: "s")           # key: "system", value: "s" (short code)
  #   end
  #
  # Different key types (symbols, integers, classes):
  #   class MixedEnum < Unmagic::Enum
  #     # Keys preserve their original type
  #     SYMBOL = new(:active)                        # key is :active (Symbol)
  #     INTEGER = new(1, value: "one")               # key is 1 (Integer)
  #     CLASS = new(User)                            # key is User (Class)
  #   end
  #
  # STI (Single Table Inheritance) integration:
  #   class User < ApplicationRecord
  #     class Type < Unmagic::Enum
  #       # Pass the actual class - no constantize needed!
  #       CUSTOMER = new(Customer)                   # key: Customer class, value: "Customer"
  #       ADMIN = new(Admin, value: "a")            # key: Admin class, value: "a"
  #       MODERATOR = new(Moderator)                # key: Moderator class, value: "Moderator"
  #     end
  #
  #     attribute :type, Type.column_type
  #
  #     # Clean STI integration - enum.key returns the actual class
  #     def self.find_sti_class(type_name)
  #       if enum_value = Type[type_name]
  #         enum_value.key  # Returns the class directly, no constantize!
  #       else
  #         super
  #       end
  #     end
  #
  #     def self.sti_name
  #       Type.all.find { |e| e.key == self }&.value || name
  #     end
  #   end
  #
  # Usage patterns:
  #   status = Status::ACTIVE
  #   status.active?                # => true (query method)
  #   status == "active"            # => true (string equality)
  #   status == :active             # => false (symbols don't match strings)
  #   status.to_s                   # => "active" (for database)
  #
  #   # Lookups work with any type
  #   Status["active"]              # => Status::ACTIVE
  #   MixedEnum[:active]            # => MixedEnum::SYMBOL
  #   MixedEnum[1]                  # => MixedEnum::INTEGER
  #   MixedEnum[User]               # => MixedEnum::CLASS
  #
  class Enum
    class InvalidValueError < StandardError; end
    class ReservedValueError < StandardError; end

    class << self
      # Get enum instances dynamically from constants
      def instances_by_key
        # Build hash from constants each time (stateless)
        constants.each_with_object({}) do |const_name, hash|
          const = const_get(const_name)
          next unless const.is_a?(Unmagic::Enum)

          hash[const.key_string] = const
        end
      end

      # Get enum instances by value (database value)
      def instances_by_value
        # Build hash from constants each time (stateless)
        constants.each_with_object({}) do |const_name, hash|
          const = const_get(const_name)
          next unless const.is_a?(Unmagic::Enum)

          hash[const.value] = const
        end
      end

      # Backward compatibility - instances is an alias for instances_by_key
      def instances
        instances_by_key
      end

      # Declare attributes for this enum class with options
      def attribute(*names, **options)
        @attribute_metadata ||= {}

        names.each do |name|
          # Store metadata for this attribute
          @attribute_metadata[name] = options

          # Create the reader method
          attr_reader name

          # Create alias if specified
          next unless options[:alias]

          aliases = Array(options[:alias])
          aliases.each do |alias_name|
            alias_method alias_name, name

            # Track reserved method names to prevent conflicts
            @reserved_methods ||= Set.new
            @reserved_methods.add(alias_name.to_s)
          end
        end
      end

      # Get declared attributes (just the names)
      def attributes
        @attribute_metadata&.keys || []
      end

      # Get metadata for an attribute
      def attribute_metadata
        @attribute_metadata || {}
      end

      # Get reserved method names (from aliases)
      def reserved_methods
        @reserved_methods || Set.new
      end

      # Get all enum values
      def all
        instances.values
      end

      # Look up enum by key or value
      def [](lookup)
        lookup_str = lookup.to_s
        # Try key first, then value
        instances_by_key[lookup_str] || instances_by_value[lookup_str]
      end

      # Alias for [] to support dry-initializer type coercion
      # dry-initializer expects types to respond to .call with 1 argument
      def call(value)
        self[value]
      end

      # Get all valid database values (useful for validations)
      def values
        instances_by_value.keys
      end

      # Get all valid keys (identifiers used in code)
      def keys
        instances_by_key.keys
      end

      # Check if a value is valid for this enum
      def valid?(value)
        case value
        when self
          true
        when String
          instances.key?(value)
        else
          false
        end
      end

      # Ensure each subclass has its own metadata
      def inherited(subclass)
        super
        # Initialize metadata for attributes and reserved methods
        subclass.instance_variable_set(:@attribute_metadata, {})
        subclass.instance_variable_set(:@reserved_methods, Set.new)
      end
    end

    # The key (identifier used in code - preserves original type)
    attr_reader :key

    # The key as a string (used for lookups and comparisons)
    attr_reader :key_string

    # The value (what gets stored in database)
    attr_reader :value

    # Override equality to work with strings and same-class enums
    def ==(other)
      if other.is_a?(Unmagic::Enum)
        # Only equal if same class and same value
        other.class == self.class && @value == other.value
      elsif other.is_a?(String)
        # Check both key_string and value for flexibility
        [@key_string, @value].include?(other)
      else
        # Check if it matches the original key (for symbols, classes, etc.)
        @key == other
      end
    end

    # Ensure different enum classes don't match
    def eql?(other)
      other.is_a?(self.class) && to_s == other.to_s
    end

    # Hash code based on string value and class
    def hash
      [self.class, to_s].hash
    end

    # Human-readable inspect showing how to reference this enum in code
    def inspect
      # Find the constant name for this enum instance
      constant_name = self.class.constants.find do |const|
        self.class.const_get(const) == self
      end

      if constant_name
        "#{self.class.name}::#{constant_name}"
      else
        # Fallback showing how to access via bracket notation
        # Show the original key type for clarity
        "#{self.class.name}[#{@key.inspect}]"
      end
    end

    # Allow enum to be used directly in database queries and assignments
    def to_str
      to_s
    end

    # Return the database value (for serialization)
    def to_s
      @value
    end

    # Initialize the enum with key and optional value
    def initialize(key, **attributes)
      @key = key # Keep original type (class, symbol, integer, string, etc.)
      @key_string = key.to_s # String version for lookups and comparisons

      # Extract the special 'value' option, default to string version of key
      @value = attributes.delete(:value)&.to_s || @key_string

      # Check for duplicate keys
      if self.class.instances_by_key[@key_string]
        raise InvalidValueError.new("Enum key '#{@key_string}' has already been defined")
      end

      # Check for duplicate values
      existing = self.class.instances_by_value[@value]
      if existing
        raise InvalidValueError.new("Enum value '#{@value}' has already been defined for key '#{existing.key_string}'")
      end

      # Check for conflicts with reserved methods (using string key for query methods)
      key_method = "#{@key_string}?"
      if self.class.reserved_methods.include?(key_method)
        raise ReservedValueError.new("Cannot create enum key '#{@key_string}' because it would conflict with alias method '#{key_method}'")
      end

      # Set declared attributes with defaults
      self.class.attribute_metadata.each do |attr, metadata|
        value = if attributes.key?(attr)
                  attributes[attr]
                elsif metadata.key?(:default)
                  metadata[:default]
                else
                  nil
                end
        instance_variable_set("@#{attr}", value)
      end

      # Warn about undeclared attributes in development
      if defined?(Rails) && Rails.env.development?
        extra_attrs = attributes.keys - self.class.attributes
        if extra_attrs.any?
          warn "[Unmagic::Enum] Undeclared attributes passed to #{self.class.name}: #{extra_attrs.join(', ')}"
        end
      end

      freeze
    end

    # Implement query methods like `user?` for checking enum keys
    def method_missing(method_name, *args)
      if method_name.to_s.end_with?('?')
        key_to_check = method_name.to_s[0..-2] # Remove the '?'
        @key_string == key_to_check # Compare string versions
      else
        super
      end
    end

    # Properly handle respond_to? for query methods
    def respond_to_missing?(method_name, include_private = false)
      method_name.to_s.end_with?('?') || super
    end

    # Rails presence validation support - enums are never blank
    def blank?
      false
    end

    # Rails presence validation support - enums are always present
    def present?
      true
    end

    # Load ActiveRecord extensions if ActiveRecord is available
    if defined?(ActiveRecord)
      require 'unmagic/enum/active_record_extensions'
      include ActiveRecordExtensions
    end
  end
end
