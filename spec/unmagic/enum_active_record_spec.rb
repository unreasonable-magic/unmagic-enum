# frozen_string_literal: true

require 'spec_helper'

# Only run these tests if ActiveRecord is available
RSpec.describe 'Unmagic::Enum ActiveRecord integration', :activerecord do
  # Explicitly require ActiveRecord for these tests
  before(:all) do
    require 'active_record'
  end

  # Basic enum for testing ActiveRecord integration
  class ActiveRecordTestStatus < Unmagic::Enum
    ACTIVE = new('active')
    PENDING = new('pending')
    ARCHIVED = new('archived')
  end

  # Enum with key/value separation for testing custom values
  class ActiveRecordTestMessageType < Unmagic::Enum
    USER = new('user')
    ENTITY = new('entity', value: 'bot')
    SYSTEM = new('system', value: 's')
  end

  # A plain ActiveModel object exercises the same assignment path ActiveRecord
  # enums use (ActiveModel::Attribute#with_value_from_user -> assert_valid_value),
  # so the eager-raise behaviour can be tested without a database connection.
  class ActiveRecordTestRecord
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :status, ActiveRecordTestStatus.column_type
  end

  # validate: true opts out of the eager raise so model validations handle an
  # unknown value (it casts to nil) instead of the assignment blowing up.
  class ActiveRecordLenientRecord
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations

    attribute :status, ActiveRecordTestStatus.column_type(validate: true)
    validates :status, presence: true
  end

  # Multi-valued attribute backed by ArrayColumnType, the way a json/jsonb
  # column holding several enum values would be declared.
  class ActiveRecordMultiRecord
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :statuses, ActiveRecordTestStatus.column_type(array: true)
  end

  describe 'ActiveRecord extensions' do
    it 'includes ActiveRecord extensions when ActiveRecord is available' do
      expect(ActiveRecordTestStatus).to respond_to(:column_type)
      expect(ActiveRecordTestStatus::ACTIVE).to respond_to(:to_type_for_database)
    end

    describe '.column_type' do
      it 'returns an ActiveRecord type instance' do
        type = ActiveRecordTestStatus.column_type
        expect(type).to be_a(Unmagic::Enum::ActiveRecordExtensions::ColumnType)
      end

      it 'returns the correct type' do
        type = ActiveRecordTestStatus.column_type
        expect(type.type).to eq(:string)
      end
    end

    describe '#to_type_for_database' do
      it 'returns the database value' do
        expect(ActiveRecordTestStatus::ACTIVE.to_type_for_database).to eq('active')
        expect(ActiveRecordTestMessageType::ENTITY.to_type_for_database).to eq('bot')
      end
    end
  end

  describe 'ColumnType' do
    let(:column_type) { ActiveRecordTestStatus.column_type }

    describe '#cast' do
      it 'returns nil for nil' do
        expect(column_type.cast(nil)).to be_nil
      end

      it 'returns the enum instance unchanged' do
        expect(column_type.cast(ActiveRecordTestStatus::ACTIVE)).to eq(ActiveRecordTestStatus::ACTIVE)
      end

      it 'casts string to enum' do
        expect(column_type.cast('active')).to eq(ActiveRecordTestStatus::ACTIVE)
      end

      it 'returns nil for invalid values (lenient, like ActiveRecord::Enum)' do
        expect(column_type.cast('invalid')).to be_nil
      end
    end

    describe '#deserialize' do
      it 'deserializes database values' do
        expect(column_type.deserialize('active')).to eq(ActiveRecordTestStatus::ACTIVE)
      end

      it 'deserializes custom values' do
        msg_type = ActiveRecordTestMessageType.column_type
        expect(msg_type.deserialize('bot')).to eq(ActiveRecordTestMessageType::ENTITY)
      end

      it 'returns nil for nil' do
        expect(column_type.deserialize(nil)).to be_nil
      end

      it 'returns nil for empty string' do
        expect(column_type.deserialize('')).to be_nil
      end

      it 'returns nil for invalid database values (lenient, like ActiveRecord::Enum)' do
        expect(column_type.deserialize('invalid')).to be_nil
      end
    end

    describe '#assert_valid_value' do
      it 'passes for nil and empty string' do
        expect { column_type.assert_valid_value(nil) }.not_to raise_error
        expect { column_type.assert_valid_value('') }.not_to raise_error
      end

      it 'passes for an enum instance' do
        expect { column_type.assert_valid_value(ActiveRecordTestStatus::ACTIVE) }.not_to raise_error
      end

      it 'passes for a known value' do
        expect { column_type.assert_valid_value('active') }.not_to raise_error
      end

      it 'raises for an unknown value' do
        expect { column_type.assert_valid_value('invalid') }.to raise_error(
          Unmagic::Enum::InvalidValueError,
          /Invalid ActiveRecordTestStatus value/
        )
      end

      context 'with validate: true' do
        let(:lenient_type) { ActiveRecordTestStatus.column_type(validate: true) }

        it 'does not raise for an unknown value' do
          expect { lenient_type.assert_valid_value('invalid') }.not_to raise_error
        end

        it 'still casts a known value and nils an unknown one' do
          expect(lenient_type.cast('active')).to eq(ActiveRecordTestStatus::ACTIVE)
          expect(lenient_type.cast('invalid')).to be_nil
        end

        it 'memoises a distinct instance per option value' do
          expect(ActiveRecordTestStatus.column_type(validate: true))
            .to be(ActiveRecordTestStatus.column_type(validate: true))
          expect(ActiveRecordTestStatus.column_type(validate: true))
            .not_to be(ActiveRecordTestStatus.column_type)
        end
      end
    end

    describe '#serialize' do
      it 'serializes enum to database value' do
        expect(column_type.serialize(ActiveRecordTestStatus::ACTIVE)).to eq('active')
      end

      it 'serializes custom values correctly' do
        msg_type = ActiveRecordTestMessageType.column_type
        expect(msg_type.serialize(ActiveRecordTestMessageType::ENTITY)).to eq('bot')
      end

      it 'serializes nil to nil' do
        expect(column_type.serialize(nil)).to be_nil
      end
    end

    describe '#changed_in_place?' do
      it 'detects changes correctly' do
        expect(column_type.changed_in_place?('active', ActiveRecordTestStatus::ACTIVE)).to be false
        expect(column_type.changed_in_place?('pending', ActiveRecordTestStatus::ACTIVE)).to be true
        expect(column_type.changed_in_place?(nil, ActiveRecordTestStatus::ACTIVE)).to be true
        expect(column_type.changed_in_place?('active', nil)).to be true
      end
    end
  end

  describe 'assignment behaviour (consistent with ActiveRecord::Enum)' do
    it 'casts a known value to its enum instance' do
      expect(ActiveRecordTestRecord.new(status: 'active').status).to eq(ActiveRecordTestStatus::ACTIVE)
    end

    it 'accepts an enum instance' do
      expect(ActiveRecordTestRecord.new(status: ActiveRecordTestStatus::PENDING).status)
        .to eq(ActiveRecordTestStatus::PENDING)
    end

    it 'treats blank as nil' do
      expect(ActiveRecordTestRecord.new(status: '').status).to be_nil
      expect(ActiveRecordTestRecord.new(status: nil).status).to be_nil
    end

    it 'raises eagerly when an invalid value is assigned (not lazily on read)' do
      record = ActiveRecordTestRecord.new
      expect { record.status = 'invalid' }.to raise_error(
        Unmagic::Enum::InvalidValueError,
        /Invalid ActiveRecordTestStatus value/
      )
    end

    it 'raises on mass-assignment of an invalid value' do
      expect { ActiveRecordTestRecord.new(status: 'invalid') }.to raise_error(
        Unmagic::Enum::InvalidValueError
      )
    end

    context 'with validate: true' do
      it 'assigns an unknown value as nil instead of raising' do
        record = ActiveRecordLenientRecord.new
        expect { record.status = 'invalid' }.not_to raise_error
        expect(record.status).to be_nil
      end

      it 'lets a model validation flag the unknown (now nil) value' do
        record = ActiveRecordLenientRecord.new(status: 'invalid')
        expect(record.valid?).to be false
        expect(record.errors[:status]).to be_present
      end

      it 'still accepts a known value' do
        record = ActiveRecordLenientRecord.new(status: 'active')
        expect(record.valid?).to be true
        expect(record.status).to eq(ActiveRecordTestStatus::ACTIVE)
      end
    end
  end

  describe 'ArrayColumnType' do
    let(:array_type) { ActiveRecordTestStatus.column_type(array: true) }

    describe '.column_type(array: true)' do
      it 'returns an array type instance' do
        expect(array_type).to be_a(Unmagic::Enum::ActiveRecordExtensions::ArrayColumnType)
      end

      it 'reports a json column type' do
        expect(array_type.type).to eq(:json)
      end

      it 'memoises a distinct instance per option set' do
        expect(ActiveRecordTestStatus.column_type(array: true))
          .to be(ActiveRecordTestStatus.column_type(array: true))
        expect(ActiveRecordTestStatus.column_type(array: true))
          .not_to be(ActiveRecordTestStatus.column_type)
        expect(ActiveRecordTestStatus.column_type(array: true, validate: true))
          .not_to be(ActiveRecordTestStatus.column_type(array: true))
      end
    end

    describe '#cast' do
      it 'casts an array of strings to enum instances' do
        expect(array_type.cast(%w[active pending]))
          .to eq([ActiveRecordTestStatus::ACTIVE, ActiveRecordTestStatus::PENDING])
      end

      it 'passes enum instances through' do
        expect(array_type.cast([ActiveRecordTestStatus::ACTIVE])).to eq([ActiveRecordTestStatus::ACTIVE])
      end

      it 'wraps a single value' do
        expect(array_type.cast('active')).to eq([ActiveRecordTestStatus::ACTIVE])
      end

      it 'casts nil to an empty array' do
        expect(array_type.cast(nil)).to eq([])
      end

      it 'drops blank elements (the entry a check-box collection hidden field submits)' do
        expect(array_type.cast(['', 'active'])).to eq([ActiveRecordTestStatus::ACTIVE])
      end

      it 'drops unknown elements (lenient, like ColumnType#cast)' do
        expect(array_type.cast(%w[invalid active])).to eq([ActiveRecordTestStatus::ACTIVE])
      end
    end

    describe '#deserialize' do
      it 'deserializes a JSON document of database values' do
        expect(array_type.deserialize('["active","pending"]'))
          .to eq([ActiveRecordTestStatus::ACTIVE, ActiveRecordTestStatus::PENDING])
      end

      it 'deserializes custom values' do
        msg_type = ActiveRecordTestMessageType.column_type(array: true)
        expect(msg_type.deserialize('["bot"]')).to eq([ActiveRecordTestMessageType::ENTITY])
      end

      it 'deserializes an already-decoded array' do
        expect(array_type.deserialize(%w[active])).to eq([ActiveRecordTestStatus::ACTIVE])
      end

      it 'returns an empty array for nil and empty string' do
        expect(array_type.deserialize(nil)).to eq([])
        expect(array_type.deserialize('')).to eq([])
      end

      it 'drops database values the enum no longer recognises' do
        expect(array_type.deserialize('["invalid","active"]')).to eq([ActiveRecordTestStatus::ACTIVE])
      end
    end

    describe '#assert_valid_value' do
      it 'passes for nil, blank elements, and known elements' do
        expect { array_type.assert_valid_value(nil) }.not_to raise_error
        expect { array_type.assert_valid_value(['', 'active']) }.not_to raise_error
        expect { array_type.assert_valid_value([ActiveRecordTestStatus::ACTIVE]) }.not_to raise_error
      end

      it 'raises for an unknown element' do
        expect { array_type.assert_valid_value(%w[active invalid]) }.to raise_error(
          Unmagic::Enum::InvalidValueError,
          /Invalid ActiveRecordTestStatus value/
        )
      end

      context 'with validate: true' do
        let(:lenient_type) { ActiveRecordTestStatus.column_type(array: true, validate: true) }

        it 'does not raise for an unknown element' do
          expect { lenient_type.assert_valid_value(%w[invalid]) }.not_to raise_error
        end

        it 'drops the unknown element on cast' do
          expect(lenient_type.cast(%w[invalid active])).to eq([ActiveRecordTestStatus::ACTIVE])
        end
      end
    end

    describe '#serialize' do
      it 'serializes enum instances to a JSON document of database values' do
        expect(array_type.serialize([ActiveRecordTestStatus::ACTIVE, ActiveRecordTestStatus::PENDING]))
          .to eq('["active","pending"]')
      end

      it 'serializes custom values correctly' do
        msg_type = ActiveRecordTestMessageType.column_type(array: true)
        expect(msg_type.serialize([ActiveRecordTestMessageType::ENTITY])).to eq('["bot"]')
      end

      it 'serializes an empty array to an empty JSON document' do
        expect(array_type.serialize([])).to eq('[]')
      end

      it 'serializes nil to nil' do
        expect(array_type.serialize(nil)).to be_nil
      end
    end

    describe '#changed_in_place?' do
      it 'detects in-place mutation by comparing serialized forms' do
        expect(array_type.changed_in_place?('["active"]', [ActiveRecordTestStatus::ACTIVE])).to be false
        expect(array_type.changed_in_place?(
                 '["active"]',
                 [ActiveRecordTestStatus::ACTIVE, ActiveRecordTestStatus::PENDING]
               )).to be true
      end

      it 'treats order as significant' do
        expect(array_type.changed_in_place?(
                 '["active","pending"]',
                 [ActiveRecordTestStatus::PENDING, ActiveRecordTestStatus::ACTIVE]
               )).to be true
      end
    end
  end

  describe 'array assignment behaviour' do
    it 'casts assigned values to enum instances' do
      record = ActiveRecordMultiRecord.new(statuses: %w[active pending])
      expect(record.statuses).to eq([ActiveRecordTestStatus::ACTIVE, ActiveRecordTestStatus::PENDING])
    end

    it 'drops the blank entry a check-box collection submits' do
      record = ActiveRecordMultiRecord.new(statuses: ['', 'active'])
      expect(record.statuses).to eq([ActiveRecordTestStatus::ACTIVE])
    end

    it 'casts an assigned nil to an empty array' do
      expect(ActiveRecordMultiRecord.new(statuses: nil).statuses).to eq([])
    end

    it 'raises eagerly when an unknown element is assigned' do
      expect { ActiveRecordMultiRecord.new(statuses: %w[invalid]) }.to raise_error(
        Unmagic::Enum::InvalidValueError,
        /Invalid ActiveRecordTestStatus value/
      )
    end
  end
end
