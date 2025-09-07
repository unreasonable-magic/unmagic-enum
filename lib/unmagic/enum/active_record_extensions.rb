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

        # Cast value from user input (e.g., form params, setter methods)
        def cast(value)
          return nil if value.nil?
          return value if value.is_a?(@enum_class)

          # Try to find the enum instance by string value
          result = @enum_class[value.to_s]
          unless result
            raise Unmagic::Enum::InvalidValueError, "Invalid #{@enum_class.name} value: #{value.inspect}"
          end
          result
        end

        # Deserialize value from database
        def deserialize(value)
          return nil if value.nil?
          result = @enum_class[value]
          unless result
            raise Unmagic::Enum::InvalidValueError, "Invalid #{@enum_class.name} value in database: #{value.inspect}"
          end
          result
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