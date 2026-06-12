# frozen_string_literal: true

# ActiveRecord extensions for Unmagic::Enum
# This module provides database type casting and serialization support
module Unmagic
  class Enum
    module ActiveRecordExtensions
      class ColumnType < ActiveRecord::Type::Value
        # `validate:` mirrors ActiveRecord::Enum's option of the same name. It
        # defaults to false, matching Rails: an unknown value is rejected eagerly
        # on assignment (see #assert_valid_value). Pass validate: true to opt out
        # of the eager raise so model validations handle the unknown value
        # instead — it casts to nil, so a `presence`/`inclusion` validation can
        # flag it rather than the assignment blowing up.
        def initialize(enum_class, validate: false)
          @enum_class = enum_class
          @raise_on_invalid_values = !validate
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
        # nil); an enum instance or a known key/value passes. When the type was
        # built with validate: true the eager raise is suppressed (the value then
        # casts to nil), matching ActiveRecord::Enum's raise_on_invalid_values.
        def assert_valid_value(value)
          return unless @raise_on_invalid_values
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

      # A column that stores multiple values of one enum, as a JSON array of the
      # enum's database values (a `json`/`jsonb` column). Each element gets the
      # same treatment ColumnType gives a single value: cast to an enum
      # instance, validated eagerly on assignment, serialized to its database
      # value. Blank elements are dropped during cast — so the blank entry a
      # check-box collection's auxiliary hidden field submits never reaches the
      # stored array — and unknown stored values are dropped on read, so the
      # attribute always reads as an array of valid enum instances (never nil).
      class ArrayColumnType < ActiveRecord::Type::Value
        def initialize(enum_class, validate: false)
          @enum_class = enum_class
          @element_type = ColumnType.new(enum_class, validate: validate)
          super()
        end

        def type
          :json
        end

        # Cast to an array of enum instances. A single value wraps into a
        # one-element array; nil casts to []. Elements cast leniently like
        # ColumnType#cast (blank or unknown resolves to nil) and are compacted
        # away — eager rejection of unknowns happens in #assert_valid_value.
        def cast(value)
          Array(value).map { |element| @element_type.cast(element) }.compact
        end

        # Deserialize the database's JSON document. Lenient like
        # ColumnType#deserialize: an element the enum no longer recognises is
        # dropped rather than raising on read.
        def deserialize(value)
          return [] if value.nil? || value == ''

          value = ActiveSupport::JSON.decode(value) if value.is_a?(::String)

          Array(value).map { |element| @element_type.deserialize(element) }.compact
        end

        # Validate each element at assignment time, the way ColumnType does for
        # a single value: blanks are allowed (they're dropped by #cast); an
        # unknown element raises unless the type was built with validate: true.
        def assert_valid_value(value)
          Array(value).each { |element| @element_type.assert_valid_value(element) }
        end

        # Serialize to a JSON array of database values for storage.
        def serialize(value)
          return nil if value.nil?

          ActiveSupport::JSON.encode(Array(value).map { |element| @element_type.serialize(element) })
        end

        # Detect in-place mutation (e.g. `record.statuses << Status::ACTIVE`)
        # by comparing the serialized forms. Order is significant.
        def changed_in_place?(raw_old_value, new_value)
          serialize(new_value) != raw_old_value
        end
      end

      module ClassMethods
        # For ActiveRecord attribute type definition. `validate:` mirrors
        # ActiveRecord::Enum (default false = raise eagerly on an unknown value;
        # true = let model validations handle it). `array: true` returns a type
        # for columns holding multiple values of the enum as a JSON array.
        # Memoised per option set.
        def column_type(validate: false, array: false)
          (@column_types ||= {})[[validate, array]] ||= if array
            Unmagic::Enum::ActiveRecordExtensions::ArrayColumnType.new(self, validate: validate)
          else
            Unmagic::Enum::ActiveRecordExtensions::ColumnType.new(self, validate: validate)
          end
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
