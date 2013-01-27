require 'multi_json'
require 'repository/base'
require 'repository/cursor'

module Repository
  class Memory < Base

    def initialize(model_klass, options={})
      @model_klass = model_klass
      @id = 0
      @store = {}
    end

    def find_by_id(id)
      id_eq(id).first
    end

    ###########################
    # These methods are called by the cursor. Do not call them directly. Or call them. Whatever. Either one.

    def execute_find(query)
      models = all_models
      models = filter_models models, query[:filters]
      models = sort_models   models, query[:sorts]
      models = offset_models models, query[:offset]
      models = limit_models  models, query[:limit]
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

    def id_eq(value)
      Cursor.new(self).eq(:id, value)
    end

    def filter_models(models, filters)
      models.select do |model|
        (filters || []).all? do |filter|
          value = model.send(filter.field.to_sym)
          case filter.operator
          when '='; value == filter.value
          when '!='; value != filter.value
          when '<'; value && value < filter.value
          when '<='; value && value <= filter.value
          when '>'; value && value > filter.value
          when '>='; value && value >= filter.value
          when 'in'; filter.value.include?(value)
          when '!in'; !filter.value.include?(value)
          end
        end
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
      field1, field2 = model1.send(sort.field), model2.send(sort.field)
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
        model_klass.new(MultiJson.load(raw_record))
      end
    end

    def store_record!(record)
      _id = record[:id] || id
      @store[_id] = MultiJson.dump(record.merge(id: _id))
      _id
    end

    def remove_model!(model)
      @store.delete(model.id)
      nil
    end

    def build_model(raw_record)
    end

    def id
      @id += 1
    end
  end
end
