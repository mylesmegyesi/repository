require 'active_record'
require 'repository/base'

module Repository
  class ActiveRecord < Base

    def initialize(model_klass, options={})
      @model_klass        = model_klass
      @domain_model_klass = options[:domain_model_klass]
    end

    def create!(model_or_hash={})
      attrs = model_or_hash_as_attrs(model_or_hash)
      build_domain_model(model_klass.create!(attrs))
    end

    def update!(model_or_id, attrs={})
      attributes = attrs || {}
      case
      when model_or_id.is_a?(model_klass)
        if model_or_id.persisted?
          model_or_id.update_attributes(attributes)
          build_domain_model(model_or_id)
        else
          raise ArgumentError.new("Could not update record with id: #{model_or_id.send(primary_key)} because it does not exist")
        end
      when model_or_id.is_a?(domain_model_klass)
        id = model_or_id.send(primary_key)
        if model = model_klass.where(primary_key => id).first
          update!(model, model_or_id.attributes.merge(attributes))
        else
          raise ArgumentError.new("Could not update record with id: #{id} because it does not exist")
        end
      else
        if model = model_klass.where(primary_key => model_or_id).first
          update!(model, attributes)
        else
          raise ArgumentError.new("Could not update record with id: #{model_or_id} because it does not exist")
        end
      end
    end

    def find_by_id(id)
      self.find.eq(model_klass.primary_key, id).first
    end

    def execute_find(query)
      scope = apply_filters model_klass, query[:filters]
      scope = apply_sorts   scope,       query[:sorts]
      scope = apply_limit   scope,       query[:limit]
      scope = apply_offset  scope,       query[:offset]
      scope.all.map { |m| build_domain_model(m) }
    end

    def execute_count(query)
      apply_filters(model_klass, query[:filters]).count
    end

    def execute_remove!(query)
      apply_filters(model_klass, query[:filters]).delete_all
    end

    private

    attr_reader :domain_model_klass

    def update_data(model_or_id)
      case
      when model_or_id.is_a?(model_klass)
        [model_or_id.send(primary_key), model_or_id.attributes.slice(*model_or_id.changed)]
      when model_or_id.is_a?(domain_model_klass)
        [model_or_id.send(primary_key), model_or_id.attributes]
      else
        [model_or_id, {}]
      end
    end

    def build_domain_model(model)
      if domain_model_klass
        domain_model_klass.new(model.attributes)
      else
        model
      end
    end

    def apply_filters(scope, filters)
      apply_filter(scope, Filter.new(nil, 'and', filters))
    end

    class FakeScope

      attr_reader :wheres, :variables

      def initialize
        @wheres = []
        @variables = []
      end

      def where(sql, *varaiables)
        @wheres << sql
        @variables += varaiables
        self
      end

    end

    def apply_filter(scope, filter)
      column = quoted_column(filter.field)
      case filter.operator
      when '='
        if filter.value
          scope.where("#{column} = ?", filter.value)
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
        scope.where("#{column} < ?", filter.value)
      when '<='
        scope.where("#{column} <= ?", filter.value)
      when '>'
        scope.where("#{column} > ?", filter.value)
      when '>='
        scope.where("#{column} >= ?", filter.value)
      when 'in'
        apply_contains_filter(scope, column, filter.value, '', lambda { |str|
          "(#{str} AND #{column} IS NOT NULL)"
        }, lambda { |str|
          "(#{str} OR #{column} IS NULL)"
        })
      when '!in'
        non_nil_values, nil_values = filter.value.uniq.partition { |val| !val.nil? }
        case
        when non_nil_values.empty? && nil_values.empty?
          scope
        when non_nil_values.empty? && !nil_values.empty?
          scope.where("#{column} IS NOT NULL")
        when !non_nil_values.empty? && nil_values.empty?
          scope.where("(#{column} NOT IN (?) OR #{column} IS NULL)", non_nil_values)
        when !non_nil_values.empty? && !nil_values.empty?
          scope.where("(#{column} NOT IN (?) AND #{column} IS NOT NULL)", non_nil_values)
        end
      when 'like'
        scope.where("#{column} LIKE #{glob(filter.value)}")
      when 'or'
        apply_and_join_filters(scope, filter.value, ' OR ')
      when 'and'
        apply_and_join_filters(scope, filter.value, ' AND ')
      else
        scope
      end
    end

    def apply_and_join_filters(scope, filters, join)
      fake_scope = FakeScope.new
      filters.each do |filter|
        apply_filter(fake_scope, filter)
      end
      sql = fake_scope.wheres.join(join)
      sql = "(#{sql})" if fake_scope.wheres.size > 1
      scope.where(sql, *fake_scope.variables)
    end

    def apply_contains_filter(scope, column, values, _not, if_nil, if_not_nil)
      non_nil_values, nil_values = values.uniq.partition { |val| !val.nil? }
      str = "#{column} #{_not} IN (?)"
      if nil_values.empty?
        str = if_nil.call(str)
      else
        str = if_not_nil.call(str)
      end
      scope.where(str, non_nil_values)
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
      ::ActiveRecord::Base.connection.quote_column_name(column)
    end

    def quoted_value(value)
      ::ActiveRecord::Base.connection.quote(value)
    end

    def glob(k)
      quoted_value("%#{k}%")
    end

    def store_record!(attrs)
      record = attrs.dup
      if id = record.delete(primary_key)
        model_klass.update_all(record, {primary_key => id}, {limit: 1})
      else
        model_klass.create!(record)
      end
    end

    def primary_key
      model_klass.primary_key
    end

    def remove_model!(model)
      model_klass.delete_all(id: model.id)
    end

  end
end
