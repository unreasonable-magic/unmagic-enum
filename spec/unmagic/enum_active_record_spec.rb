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
  end
end
