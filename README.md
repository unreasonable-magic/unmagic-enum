# Unmagic::Enum

Type-safe enums with attributes for Rails applications.

## Features

- Type-safe enumeration values with string storage
- Custom attributes with defaults and aliases
- ActiveRecord integration with custom column type
- STI (Single Table Inheritance) support
- Query methods for checking enum values
- Duplicate key/value detection
- Works with symbols, integers, classes as keys

## Installation

Add to your Gemfile:

```ruby
gem 'unmagic-enum'
```

## Usage

### Basic Enum

```ruby
class Status < Unmagic::Enum
  ACTIVE = new("active")
  PENDING = new("pending")
  ARCHIVED = new("archived")
end

# Usage
status = Status::ACTIVE
status.active?              # => true
status == "active"          # => true
status.to_s                 # => "active"
Status["active"]            # => Status::ACTIVE
```

### Enum with Attributes

```ruby
class Priority < Unmagic::Enum
  attribute :label
  attribute :color
  attribute :level, default: 0

  HIGH = new("high", label: "High Priority", color: "red", level: 3)
  MEDIUM = new("medium", label: "Medium Priority", color: "yellow", level: 2)
  LOW = new("low", label: "Low Priority", color: "green", level: 1)
end

priority = Priority::HIGH
priority.label              # => "High Priority"
priority.color              # => "red"
priority.level              # => 3
```

### ActiveRecord Integration

```ruby
class Message < ApplicationRecord
  class State < Unmagic::Enum
    DRAFT = new("draft")
    SENT = new("sent")
    DELIVERED = new("delivered")
  end

  # Use the column type for proper serialization
  attribute :state, State.column_type
  
  # Create scopes
  scope :delivered, -> { where(state: State::DELIVERED) }
end

# Usage
message = Message.new(state: "sent")
message.state               # => Message::State::SENT
message.state.sent?         # => true
```

### Key/Value Separation

Useful when database values differ from code identifiers:

```ruby
class MessageType < Unmagic::Enum
  USER = new("user")                    # key and value both "user"
  ENTITY = new("entity", value: "bot")  # key: "entity", value: "bot" (legacy DB)
  SYSTEM = new("system", value: "s")    # key: "system", value: "s" (short code)
end

MessageType::ENTITY.key     # => "entity"
MessageType::ENTITY.value   # => "bot"
MessageType["bot"]          # => MessageType::ENTITY
```

### STI Support

```ruby
class User < ApplicationRecord
  class Type < Unmagic::Enum
    # Pass the actual class - no constantize needed!
    CUSTOMER = new(Customer)
    ADMIN = new(Admin)
    MODERATOR = new(Moderator)
  end

  attribute :type, Type.column_type

  def self.find_sti_class(type_name)
    if enum_value = Type[type_name]
      enum_value.key  # Returns the class directly
    else
      super
    end
  end
end
```

## Development

After checking out the repo, install dependencies and run the tests:

```bash
bundle install
bundle exec rake spec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/unreasonable-magic/unmagic-enum.

## License

Released under the [MIT License](LICENSE).