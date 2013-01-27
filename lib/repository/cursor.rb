require 'repository/filter'
require 'repository/sort'

module Repository
  class Cursor

    def initialize(query_executor)
      @query_executor = query_executor
      @filters = []
      @sorts = []
      @limit = nil
      @offset = nil
    end

    def eq(field, value)
      assert_field!(field)
      @filters << Filter.new(field, '=', value)
      self
    end

    def not_eq(field, value)
      assert_field!(field)
      @filters << Filter.new(field, '!=', value)
      self
    end

    def lt(field, value)
      assert_field!(field)
      assert_not_nil!('Less than', value)
      @filters << Filter.new(field, '<', value)
      self
    end

    def lte(field, value)
      assert_field!(field)
      assert_not_nil!('Less than or equal to', value)
      @filters << Filter.new(field, '<=', value)
      self
    end

    def gt(field, value)
      assert_field!(field)
      assert_not_nil!('Greater than', value)
      @filters << Filter.new(field, '>', value)
      self
    end

    def gte(field, value)
      assert_field!(field)
      assert_not_nil!('Greater than or equal to', value)
      @filters << Filter.new(field, '>=', value)
      self
    end

    def in(field, value)
      assert_field!(field)
      assert_to_a!('Inclusion', value)
      @filters << Filter.new(field, 'in', value.to_a)
      self
    end

    def not_in(field, value)
      assert_field!(field)
      assert_to_a!('Exclusion', value)
      @filters << Filter.new(field, '!in', value.to_a)
      self
    end

    def sort(field, order)
      assert_field!(field)
      assert_order!(order)
      @sorts << Sort.new(field, order.to_sym)
      self
    end

    def limit(limit)
      if limit
        assert_int!('Limit', limit)
        @limit = limit.to_i
      end
      self
    end

    def offset(offset)
      if offset
        assert_int!('Offset', offset)
        @offset = offset.to_i
      end
      self
    end

    def count
      query_executor.execute_count(query)
    end

    def all
      query_executor.execute_find(query)
    end

    def remove!
      query_executor.execute_remove!(query)
    end

    def first
      query_executor.execute_find(
        query.merge(
          sorts: sorts_for_first,
          limit: 1
        )).first
    end

    def last
      query_executor.execute_find(
        query.merge(
          sorts: sorts_for_last,
          limit: 1
        )).first
    end

    private

    attr_reader :query_executor

    def query
      {
        :filters => @filters,
        :sorts   => @sorts,
        :offset  => @offset,
        :limit   => @limit
      }
    end

    def sorts_for_first
      if @sorts.empty?
        [Sort.new(:created_at, :desc)]
      else
        @sorts
      end
    end

    def sorts_for_last
      sorts_for_first.map do |sort|
        Sort.new(sort.field, sort.order == :asc ? :desc : :asc)
      end
    end

    def assert_field!(field)
      unless field.is_a?(String) || field.is_a?(Symbol)
        raise ArgumentError.new "Field name must be a String or Symbol but you gave #{PP.pp(field, '')}"
      end
    end

    def assert_not_nil!(name, value)
      if value.nil?
        raise ArgumentError.new "#{name} filter value cannot be nil"
      end
    end

    def assert_to_a!(name, value)
      unless value.respond_to?(:to_a)
        raise ArgumentError.new "#{name} filter value must respond to to_a but #{PP.pp(value, '')} does not"
      end
    end

    def assert_order!(order)
      unless [:asc, :desc, 'asc', 'desc'].include?(order)
        raise ArgumentError.new "Sort order must be 'asc' or 'desc' but you gave #{PP.pp(order, '')}"
      end
    end

    def assert_int!(name, num)
      unless num.is_a?(Integer) || (num.is_a?(String) && num =~ /\d+/)
        raise ArgumentError.new "#{name} must be an integer but you gave #{PP.pp(num, '')}"
      end
    end
  end
end
