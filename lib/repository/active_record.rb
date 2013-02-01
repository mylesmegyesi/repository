require 'active_record'
require 'repository/base'

module Repository
  class ActiveRecord < Base

    def initialize(model_klass, options={})
      @model_klass = model_klass
    end

    def find_by_id(id)
      model_klass.find_by_id(id)
    end

    def execute_find(query)
      scope = apply_filters model_klass, query[:filters]
      scope = apply_sorts   scope,       query[:sorts]
      scope = apply_limit   scope,       query[:limit]
      scope = apply_offset  scope,       query[:offset]
      scope.all
    end

    def execute_count(query)
      apply_filters(model_klass, query[:filters]).count
    end

    def execute_remove!(query)
      apply_filters(model_klass, query[:filters]).delete_all
    end

    private

    def apply_filters(scope, filters)
      filters.reduce(scope) do |scope, filter|
        column = quoted_column(filter.field)
        case filter.operator
        when '='
          if filter.value
            scope.where("#{column} = ? AND #{column} IS NOT NULL", filter.value)
          else
            scope.where("#{column} IS NULL")
          end
        when '!='
          if filter.value
            scope.where("#{column} <> ? OR #{column} IS NULL", filter.value)
          else
            scope.where("#{column} IS NOT NULL")
          end
        when '<'
          apply_filter(scope, column, '<', filter.value)
        when '<='
          apply_filter(scope, column, '<=', filter.value)
        when '>'
          apply_filter(scope, column, '>', filter.value)
        when '>='
          apply_filter(scope, column, '>=', filter.value)
        when 'in'
          apply_contains_filter(scope, column, filter.value, '', lambda { |str|
            "#{str} AND #{column} IS NOT NULL"
          }, lambda { |str|
            "#{str} OR #{column} IS NULL"
          })
        when '!in'
          apply_contains_filter(scope, column, filter.value, 'NOT', lambda { |str|
            "#{str} OR #{column} IS NULL"
          }, lambda { |str|
            "#{str} AND #{column} IS NOT NULL"
          })
        else
          scope
        end
      end
    end

    def apply_filter(scope, column, operator, value)
      scope.where("#{column} #{operator} ?", value)
    end

    def apply_contains_filter(scope, column, values, _not, if_nil, if_not_nil)
      non_nil_values, nil_values = values.uniq.partition { |val| !val.nil? }
      subs = (0...non_nil_values.size).map {|i| '?'}.join(', ')
      str = "#{column} #{_not} IN (#{subs})"
      if nil_values.empty?
        str = if_nil.call(str)
      else
        str = if_not_nil.call(str)
      end
      scope.where(str, *non_nil_values)
    end

    def apply_sorts(scope, sorts)
      if sorts.empty?
        scope
      else
         ar_sorts = sorts.reduce([]) do |ar_sorts, sort|
          ar_sorts << "#{quoted_column(sort.field)} #{sort.order}"
          ar_sorts
         end.join(', ')
         scope.order ar_sorts
      end
    end

    def apply_limit(scope, limit)
      if limit
        scope.limit(limit)
      else
        scope
      end
    end

    def apply_offset(scope, offset)
      if offset
        scope.offset(offset)
      else
        scope
      end
    end

    def quoted_column(column)
      model_klass.connection.quote_column_name(column)
    end

    def store_record!(record)
      if id = record.delete(:id)
        model_klass.update_all(record, {id: id}, {limit: 1})
      else
        model_klass.create!(record)
      end
    end

    def remove_model!(model)
      model_klass.delete_all(id: model.id)
    end

  end
end
