# frozen_string_literal: true

begin
  require "active_record"
rescue LoadError
  # ActiveRecord is optional
end

require "unmagic/enum"