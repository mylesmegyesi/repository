require 'multi_json'
require 'repository/base'
require 'repository/cursor'

# for sorting on booleans
class FalseClass
  def <(other)
    other
  end

  def >(other)
    false
  end
end

class TrueClass
  def <(other)
    other
  end

  def >(other)
    true
  end
end

module Repository
  class Memory < Base

    def initialize(model_klass, options={})
      @model_klass = model_klass
      @id = 0
      @store = {}
      @primary_key = options[:primary_key]
    end

    def create!(attrs={})
      _id = id
      attrs = model_or_hash_as_attrs(attrs)
      verify_attributes!(attrs)
      attributes = attrs.merge(primary_key => _id)
      store!(_id, attributes)
      model_klass.new(attributes)
    end

    def update!(model_or_id, attributes={})
      attributes ||= {}
      model = case
              when model_or_id.is_a?(model_klass)
                if model = find_by_id(model_or_id.send(primary_key))
                  model_or_id
                else
                  raise ArgumentError.new("Could not update record with id: #{model_or_id.send(primary_key)} because it does not exist") unless model
                end

              else
                if model = find_by_id(model_or_id)
                  model
                else
                  raise ArgumentError.new("Could not update record with id: #{model_or_id} because it does not exist") unless model
                end
              end
      updated_attrs = model.attributes.merge(attributes_without_pkey(attributes))
      store!(model.send(primary_key), updated_attrs)
      model_klass.new(updated_attrs)
    end

    def find_by_id(id)
      find.eq(primary_key, id).first
    end

    ###########################
    # These methods are called by the cursor. Do not call them directly. Or call them. Whatever. Either one.

    def raw_find(query)
      models = all_models
      models = apply_transforms models, query[:transforms]
      models = filter_models    models, query[:filters]
      models = sort_models      models, query[:sorts]
      models = offset_models    models, query[:offset]
      models = limit_models     models, query[:limit]
    end

    def execute_find(query)
      models = raw_find(query)
      models.map { |h| model_klass.new(h) }
    end

    def execute_count(query)
      execute_find(query).size
    end

    def execute_remove!(query)
      execute_find(query).each do |model|
        remove_model!(model)
      end
    end

    ###########################

    private

    attr_reader :primary_key

    def verify_attributes!(attrs)
      null_model = model_klass.new
      allowed_attributes = null_model.attributes.keys.map(&:to_sym)
      attrs.each do |key, value|
        unless allowed_attributes.include?(key.to_sym)
          raise ArgumentError.new("Unknown attribute: #{key}")
        end
      end
    end

    def attributes_without_pkey(attributes)
      attributes.reject { |k, v| k == primary_key }
    end

    def apply_transforms(models, transforms)
      models.map do |model|
        (transforms || []).reduce(model) do |model, transform|
          transform.call(model)
        end
      end
    end

    def filter_models(models, filters)
      models.select do |model|
        (filters || []).all? do |filter|
          filter_matches?(filter, model)
        end
      end
    end

    def filter_matches?(filter, model)
      value = model[filter.field]
      case filter.operator
      when '='; value == filter.value
      when '!='; value != filter.value
      when '<'; value && value < filter.value
      when '<='; value && value <= filter.value
      when '>'; value && value > filter.value
      when '>='; value && value >= filter.value
      when 'in'; filter.value.include?(value)
      when '!in'; !filter.value.include?(value)
      when 'or'; filter.value.any? do |sub_filter|
        filter_matches?(sub_filter, model)
      end
      when 'like'; value =~ /#{filter.value}/i
      end
    end

    def sort_models(models, sorts)
      models.sort { |model1, model2| compare_models(model1, model2, sorts) }
    end

    def compare_models(model1, model2, sorts)
      sorts.each do |sort|
        result = compare_model(model1, model2, sort)
        return result if result
      end
      0
    end

    def compare_model(model1, model2, sort)
      field1, field2 = model1[sort.field], model2[sort.field]
      field1 == field2                         ?  nil :
        field1 < field2 && sort.order == :asc  ?  -1  :
        field1 > field2 && sort.order == :desc ?  -1  : 1
    end

    def limit_models(models, limit)
      if limit
        models.take(limit)
      else
        models
      end
    end

    def offset_models(models, offset)
      if offset
        models.drop(offset)
      else
        models
      end
    end

    def all_models
      @store.values.map do |raw_record|
        model_klass.new(MultiJson.load(raw_record)).attributes
      end
    end

    def store!(id, attributes)
      @store[id] = MultiJson.dump(attributes)
    end

    def remove_model!(model)
      @store.delete(model.send(primary_key))
      nil
    end

    def id
      @id += 1
    end
  end
end
