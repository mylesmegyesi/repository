require 'repository/filter'

module Repository
  class FilterFactory

    def eq(field, value)
      assert_field!(field)
      Filter.new(field, '=', value)
    end

    def not_eq(field, value)
      assert_field!(field)
      Filter.new(field, '!=', value)
    end

    def lt(field, value)
      assert_field!(field)
      assert_not_nil!('Less than', value)
      Filter.new(field, '<', value)
    end

    def lte(field, value)
      assert_field!(field)
      assert_not_nil!('Less than or equal to', value)
      Filter.new(field, '<=', value)
    end

    def gt(field, value)
      assert_field!(field)
      assert_not_nil!('Greater than', value)
      Filter.new(field, '>', value)
    end

    def gte(field, value)
      assert_field!(field)
      assert_not_nil!('Greater than or equal to', value)
      Filter.new(field, '>=', value)
    end

    def in(field, value)
      assert_field!(field)
      assert_to_a!('Inclusion', value)
      Filter.new(field, 'in', value.to_a)
    end

    def not_in(field, value)
      assert_field!(field)
      assert_to_a!('Exclusion', value)
      Filter.new(field, '!in', value.to_a)
    end

    def like(field, value)
      assert_field!(field)
      assert_str_or_sym!(value, 'Value')
      Filter.new(field, 'like', value)
    end

    def or(*filters)
      Filter.new(nil, 'or', filters)
    end

    private

    def assert_to_a!(name, value)
      unless value.respond_to?(:to_a)
        raise ArgumentError.new "#{name} filter value must respond to to_a but #{PP.pp(value, '')} does not"
      end
    end

    def assert_not_nil!(name, value)
      if value.nil?
        raise ArgumentError.new "#{name} filter value cannot be nil"
      end
    end

    def assert_field!(field)
      assert_str_or_sym!(field, 'Field name')
    end

    def assert_str_or_sym!(value, name)
      unless value.is_a?(String) || value.is_a?(Symbol)
        raise ArgumentError.new "#{name} must be a String or Symbol but you gave #{PP.pp(value, '')}"
      end
    end

  end
end
