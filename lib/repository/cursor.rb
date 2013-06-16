require 'repository/filter'
require 'repository/sort'
require 'repository/filter_factory'

module Repository
  class Cursor

    def initialize(query_executor)
      @query_executor = query_executor
      @filters = []
      @sorts   = []
    end

    def eq(field, value)
      @filters << filter_factory.eq(field, value)
      self
    end

    def not_eq(field, value)
      @filters << filter_factory.not_eq(field, value)
      self
    end

    def lt(field, value)
      @filters << filter_factory.lt(field, value)
      self
    end

    def lte(field, value)
      @filters << filter_factory.lte(field, value)
      self
    end

    def gt(field, value)
      @filters << filter_factory.gt(field, value)
      self
    end

    def gte(field, value)
      @filters << filter_factory.gte(field, value)
      self
    end

    def in(field, value)
      @filters << filter_factory.in(field, value)
      self
    end

    def not_in(field, value)
      @filters << filter_factory.not_in(field, value)
      self
    end

    def like(field, value)
      @filters << filter_factory.like(field, value)
      self
    end

    def or(*filters)
      @filters << filter_factory.or(*filters)
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

    def remove!
      query_executor.execute_remove!(query)
    end

    def first
      query_executor.execute_find(
        query.merge(
          limit: 1
        )).first
    end

    def query
      {
        :type    => @type,
        :filters => @filters,
        :sorts   => @sorts,
        :offset  => @offset,
        :limit   => @limit
      }
    end

    private

    attr_reader :query_executor

    def filter_factory
      @filter_factory ||= FilterFactory.new
    end

    def sorts_for_first
      @sorts
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
