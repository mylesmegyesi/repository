module Repository
  class Filter

    attr_reader :field, :operator, :value

    def initialize(field, operator, value)
      @field = field
      @operator = operator
      @value = value
    end

  end
end
