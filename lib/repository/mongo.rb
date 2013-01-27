require 'mongo'
require 'repository/base'
require 'repository/cursor'

module Repository
  class Mongo < Base

    def initialize(model_klass, options={})
      @collection  = options[:collection] || raise('Must supply a mongo collection object in the :collection option')
      @model_klass = model_klass
    end

    def find_by_id(id)
      id_eq(id).first
    rescue BSON::InvalidObjectId => e
      nil
    end

    def remove_by_id!(id)
      if find_by_id(id)
        id_eq(id).remove!
      else
        raise ArgumentError.new("Could not remove record with id: #{id} because it does not exist")
      end
    end

    def execute_find(query)
      mongo_cursor = collection.find(filters_to_mongo(query[:filters]))
      mongo_cursor = mongo_cursor.sort(sorts_to_mongo(query[:sorts])) unless query[:sorts].empty?
      mongo_cursor = mongo_cursor.limit(query[:limit]) if query[:limit]
      mongo_cursor = mongo_cursor.skip(query[:offset]) if query[:offset]
      mongo_cursor.map do |mongo_doc|
        build_model(mongo_doc)
      end
    end

    def execute_count(query)
      collection.find(filters_to_mongo(query[:filters])).count
    end

    def execute_remove!(query)
      collection.remove(filters_to_mongo(query[:filters]))
    end

    private

    attr_reader :collection

    def id_eq(id)
      cursor.eq('_id', BSON::ObjectId(id))
    end

    def filters_to_mongo(filters)
      return {} unless filters && !filters.empty?
      filters.group_by(&:field).reduce({}) do |mongo_filters, (field, filters)|
        equals_filter = filters.find {|f| f.operator == '='}
        if equals_filter
          if filters.size == 1
            mongo_filters[field] = equals_filter.value
          else
            raise('Cannot have multiple equality filters on the same field')
          end
        else
          mongo_filters[field] = filters.reduce({}) do |mongo_filter, filter|
            mongo_filter.merge(filter_to_mongo(filter))
          end
        end
        mongo_filters
      end
    end

    def filter_to_mongo(filter)
      case filter.operator
      when '!=';  {'$ne'  => filter.value}
      when '>';   {'$gt'  => filter.value}
      when '>=';  {'$gte' => filter.value}
      when '<';   {'$lt'  => filter.value}
      when '<=';  {'$lte' => filter.value}
      when 'in';  {'$in'  => filter.value}
      when '!in'; {'$nin' => filter.value}
      else
        raise "unsupported filter: #{filter.operator}"
      end
    end

    def sorts_to_mongo(sorts)
      sorts.reduce({}) do |mongo_sorts, sort|
        mongo_sorts[sort.field] = sort.order
        mongo_sorts
      end
    end

    def store_record!(record)
      if _id = record.delete(:id)
        collection.update({'_id' => BSON::ObjectId(_id)}, record)
      else
        collection.insert(record).to_s
      end
    end

    def remove_model!(model)
      id_eq(model.id).remove!
    end

    def blacklist_update_attrs
      super + [:_id]
    end

    def build_model(record)
      attrs = {
        id: record.delete('_id').to_s
      }.merge(record)
      model_klass.new(attrs)
    end

  end
end
