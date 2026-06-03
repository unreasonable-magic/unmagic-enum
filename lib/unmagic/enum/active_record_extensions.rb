# frozen_string_literal: true

# ActiveRecord extensions for Unmagic::Enum
# This module provides database type casting and serialization support
module Unmagic
  class Enum
    module ActiveRecordExtensions
      class ColumnType < ActiveRecord::Type::Value
        def initialize(enum_class)
          @enum_class = enum_class
          super()
        end

        def type
          :string
        end

        # Cast a value to its enum instance. Lenient, mirroring
        # ActiveRecord::Enum::EnumType#cast: an unknown value resolves to nil
        # rather than raising. Rejection of bad input happens eagerly, on
        # assignment, in #assert_valid_value (the same hook Rails enums use).
        def cast(value)
          return nil if value.nil? || value == ''
          return value if value.is_a?(@enum_class)

          @enum_class[value.to_s]
        end

        # Deserialize a database value. Lenient like #cast (and like Rails'
        # EnumType, which maps an unknown column value to nil) so that reading a
        # row never raises on data the enum no longer recognises.
        def deserialize(value)
          return nil if value.nil? || value == ''

          @enum_class[value]
        end

        # Validate a value at assignment time, the way ActiveRecord::Enum does:
        # ActiveModel::Attribute#with_value_from_user calls this before storing,
        # so an invalid value raises immediately on `record.attr = ...` instead
        # of later, lazily, when the attribute is read. Blank is allowed (becomes
        # nil); an enum instance or a known key/value passes.
        def assert_valid_value(value)
          return if value.nil? || value == ''
          return if value.is_a?(@enum_class)
          return if @enum_class[value]

          raise Unmagic::Enum::InvalidValueError, "Invalid #{@enum_class.name} value: #{value.inspect}"
        end

        # Serialize value for database storage
        def serialize(value)
          return nil if value.nil?

          value.to_s
        end

        # Check if the value has changed
        def changed_in_place?(raw_old_value, new_value)
          raw_old_value.to_s != new_value.to_s
        end
      end

      module ClassMethods
        # For ActiveRecord attribute type definition
        def column_type
          @column_type ||= Unmagic::Enum::ActiveRecordExtensions::ColumnType.new(self)
        end
      end

      module InstanceMethods
        # Support for ActiveRecord type casting in SQL queries
        # This allows Enum instances to be used directly in where clauses
        def to_type_for_database
          @value
        end
      end

      def self.included(base)
        base.extend(ClassMethods)
        base.include(InstanceMethods)
      end
    end
  end
end
