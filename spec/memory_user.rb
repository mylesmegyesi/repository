require 'virtus'

class MemoryUser
  include Virtus

  attribute :id
  attribute :name,        String
  attribute :age,         Integer
  attribute :opened_at,   Time
  attribute :created_at,  Time
  attribute :updated_at,  Time

  alias :to_h :attributes
end
