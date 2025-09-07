# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unmagic::Enum do
  # Basic enum for testing
  class TestStatus < Unmagic::Enum
    ACTIVE = new("active")
    PENDING = new("pending")
    ARCHIVED = new("archived")
  end

  # Enum with attributes
  class TestPriority < Unmagic::Enum
    attribute :label
    attribute :color
    attribute :level, default: 0

    HIGH = new("high", label: "High Priority", color: "red", level: 3)
    MEDIUM = new("medium", label: "Medium Priority", color: "yellow", level: 2)
    LOW = new("low", label: "Low Priority", color: "green", level: 1)
  end

  # Enum with key/value separation
  class TestMessageType < Unmagic::Enum
    USER = new("user")
    ENTITY = new("entity", value: "bot")
    SYSTEM = new("system", value: "s")
  end

  # Enum with different key types
  class TestMixedEnum < Unmagic::Enum
    SYMBOL = new(:active)
    INTEGER = new(1, value: "one")
    STRING = new("test")
  end

  # Enum with attribute aliases
  class TestAliasEnum < Unmagic::Enum
    attribute :display_name, alias: [:name, :title]
    
    FIRST = new("first", display_name: "First Item")
  end

  describe ".new" do
    it "creates an enum instance with a string key" do
      status = TestStatus::ACTIVE
      expect(status.key).to eq("active")
      expect(status.key_string).to eq("active")
      expect(status.value).to eq("active")
    end

    it "creates an enum with custom value" do
      msg_type = TestMessageType::ENTITY
      expect(msg_type.key).to eq("entity")
      expect(msg_type.key_string).to eq("entity")
      expect(msg_type.value).to eq("bot")
    end

    it "preserves original key type" do
      expect(TestMixedEnum::SYMBOL.key).to eq(:active)
      expect(TestMixedEnum::INTEGER.key).to eq(1)
      expect(TestMixedEnum::STRING.key).to eq("test")
    end

    it "sets attributes with defaults" do
      priority = TestPriority::HIGH
      expect(priority.label).to eq("High Priority")
      expect(priority.color).to eq("red")
      expect(priority.level).to eq(3)
    end

    it "applies default values for unspecified attributes" do
      class TestDefaultEnum < Unmagic::Enum
        attribute :name, default: "Unnamed"
        TEST = new("test")
      end
      
      expect(TestDefaultEnum::TEST.name).to eq("Unnamed")
    end

    it "freezes the enum instance" do
      expect(TestStatus::ACTIVE).to be_frozen
    end
  end

  describe "class methods" do
    describe ".all" do
      it "returns all enum instances" do
        all_statuses = TestStatus.all
        expect(all_statuses).to contain_exactly(
          TestStatus::ACTIVE,
          TestStatus::PENDING,
          TestStatus::ARCHIVED
        )
      end
    end

    describe ".[]" do
      it "looks up by key string" do
        expect(TestStatus["active"]).to eq(TestStatus::ACTIVE)
        expect(TestStatus["pending"]).to eq(TestStatus::PENDING)
      end

      it "looks up by value" do
        expect(TestMessageType["bot"]).to eq(TestMessageType::ENTITY)
        expect(TestMessageType["s"]).to eq(TestMessageType::SYSTEM)
      end

      it "looks up by original key type" do
        expect(TestMixedEnum[:active]).to eq(TestMixedEnum::SYMBOL)
        expect(TestMixedEnum[1]).to eq(TestMixedEnum::INTEGER)
        expect(TestMixedEnum["test"]).to eq(TestMixedEnum::STRING)
      end

      it "returns nil for unknown values" do
        expect(TestStatus["unknown"]).to be_nil
      end
    end

    describe ".call" do
      it "looks up by key string" do
        expect(TestStatus.call("active")).to eq(TestStatus::ACTIVE)
        expect(TestStatus.call("pending")).to eq(TestStatus::PENDING)
      end

      it "looks up by value" do
        expect(TestMessageType.call("bot")).to eq(TestMessageType::ENTITY)
        expect(TestMessageType.call("s")).to eq(TestMessageType::SYSTEM)
      end

      it "looks up by original key type" do
        expect(TestMixedEnum.call(:active)).to eq(TestMixedEnum::SYMBOL)
        expect(TestMixedEnum.call(1)).to eq(TestMixedEnum::INTEGER)
        expect(TestMixedEnum.call("test")).to eq(TestMixedEnum::STRING)
      end

      it "returns nil for unknown values" do
        expect(TestStatus.call("unknown")).to be_nil
      end

      it "behaves identically to .[]" do
        expect(TestStatus.call("active")).to eq(TestStatus["active"])
        expect(TestMessageType.call("bot")).to eq(TestMessageType["bot"])
        expect(TestMixedEnum.call(:active)).to eq(TestMixedEnum[:active])
        expect(TestStatus.call("unknown")).to eq(TestStatus["unknown"])
      end
    end

    describe ".values" do
      it "returns all database values" do
        expect(TestMessageType.values).to contain_exactly("user", "bot", "s")
      end
    end

    describe ".keys" do
      it "returns all key strings" do
        expect(TestStatus.keys).to contain_exactly("active", "pending", "archived")
      end
    end

    describe ".valid?" do
      it "validates enum instances" do
        expect(TestStatus.valid?(TestStatus::ACTIVE)).to be true
      end

      it "validates string keys" do
        expect(TestStatus.valid?("active")).to be true
        expect(TestStatus.valid?("unknown")).to be false
      end

      it "rejects other types" do
        expect(TestStatus.valid?(:active)).to be false
        expect(TestStatus.valid?(123)).to be false
      end
    end

    describe ".attributes" do
      it "returns declared attribute names" do
        expect(TestPriority.attributes).to contain_exactly(:label, :color, :level)
      end

      it "returns empty array when no attributes declared" do
        expect(TestStatus.attributes).to eq([])
      end
    end

  end

  describe "instance methods" do
    describe "#to_s" do
      it "returns the database value" do
        expect(TestStatus::ACTIVE.to_s).to eq("active")
        expect(TestMessageType::ENTITY.to_s).to eq("bot")
      end
    end

    describe "#to_str" do
      it "allows implicit string conversion" do
        result = "Status: " + TestStatus::ACTIVE
        expect(result).to eq("Status: active")
      end
    end

    describe "#inspect" do
      it "shows the constant name when available" do
        expect(TestStatus::ACTIVE.inspect).to eq("TestStatus::ACTIVE")
      end
    end

    describe "#==" do
      it "equals the same enum instance" do
        expect(TestStatus::ACTIVE).to eq(TestStatus::ACTIVE)
      end

      it "equals a string matching the key" do
        expect(TestStatus::ACTIVE).to eq("active")
      end

      it "equals a string matching the value" do
        expect(TestMessageType::ENTITY).to eq("bot")
      end

      it "equals the original key type" do
        expect(TestMixedEnum::SYMBOL).to eq(:active)
        expect(TestMixedEnum::INTEGER).to eq(1)
      end

      it "does not equal different enum values" do
        expect(TestStatus::ACTIVE).not_to eq(TestStatus::PENDING)
      end

      it "does not equal enums from different classes" do
        class OtherStatus < Unmagic::Enum
          ACTIVE = new("active")
        end
        expect(TestStatus::ACTIVE).not_to eq(OtherStatus::ACTIVE)
      end
    end

    describe "#eql? and #hash" do
      it "works correctly in hashes" do
        hash = { TestStatus::ACTIVE => "active value" }
        expect(hash[TestStatus::ACTIVE]).to eq("active value")
      end

      it "has consistent hash codes" do
        expect(TestStatus::ACTIVE.hash).to eq(TestStatus::ACTIVE.hash)
      end
    end

    describe "query methods" do
      it "responds to query methods for its key" do
        expect(TestStatus::ACTIVE.active?).to be true
        expect(TestStatus::ACTIVE.pending?).to be false
        expect(TestStatus::ACTIVE.archived?).to be false
      end

      it "handles respond_to? correctly" do
        expect(TestStatus::ACTIVE).to respond_to(:active?)
        expect(TestStatus::ACTIVE).to respond_to(:pending?)
        # All query methods with ? are handled by method_missing
        expect(TestStatus::ACTIVE).to respond_to(:unknown?)
      end
    end

    describe "#blank? and #present?" do
      it "is never blank" do
        expect(TestStatus::ACTIVE.blank?).to be false
      end

      it "is always present" do
        expect(TestStatus::ACTIVE.present?).to be true
      end
    end

    describe "attribute aliases" do
      it "creates alias methods for attributes" do
        enum = TestAliasEnum::FIRST
        expect(enum.display_name).to eq("First Item")
        expect(enum.name).to eq("First Item")
        expect(enum.title).to eq("First Item")
      end
    end
  end


  describe "error handling" do
    # Note: Duplicate detection works when constants are already defined
    # It doesn't work reliably in anonymous classes during initialization
    it "detects duplicate keys in named classes" do
      class TestDuplicateKeys < Unmagic::Enum
        FIRST = new("duplicate")
      end
      
      # Second attempt to use the same key should fail
      expect {
        TestDuplicateKeys::SECOND = TestDuplicateKeys.new("duplicate")
      }.to raise_error(Unmagic::Enum::InvalidValueError, /key 'duplicate' has already been defined/)
    end

    it "detects duplicate values in named classes" do
      class TestDuplicateValues < Unmagic::Enum
        FIRST = new("key1", value: "same_value")
      end
      
      # Second attempt to use the same value should fail
      expect {
        TestDuplicateValues::SECOND = TestDuplicateValues.new("key2", value: "same_value")
      }.to raise_error(Unmagic::Enum::InvalidValueError, /value 'same_value' has already been defined/)
    end

    it "prevents conflicts with alias methods" do
      expect {
        Class.new(Unmagic::Enum) do
          attribute :name, alias: :test?
          TEST = new("test", name: "Test")
        end
      }.to raise_error(Unmagic::Enum::ReservedValueError, /would conflict with alias method/)
    end
  end

  describe "inheritance" do
    it "allows subclasses to have their own instances" do
      class ParentEnum < Unmagic::Enum
        PARENT = new("parent")
      end

      class ChildEnum < ParentEnum
        CHILD = new("child")
      end

      expect(ParentEnum.all).to contain_exactly(ParentEnum::PARENT)
      # Child classes inherit parent constants in Ruby
      expect(ChildEnum.all).to contain_exactly(ChildEnum::CHILD, ParentEnum::PARENT)
    end

    it "each subclass has its own attribute metadata" do
      class ParentEnumWithAttrs < Unmagic::Enum
        attribute :name
        PARENT = new("parent", name: "Parent Name")
      end

      class ChildEnumWithAttrs < ParentEnumWithAttrs
        # Child classes need to declare their own attributes
        attribute :name
        attribute :description
        TEST = new("test", name: "Test Name", description: "Test Desc")
      end

      expect(ParentEnumWithAttrs::PARENT.name).to eq("Parent Name")
      expect(ChildEnumWithAttrs::TEST.name).to eq("Test Name")
      expect(ChildEnumWithAttrs::TEST.description).to eq("Test Desc")
    end
  end
end