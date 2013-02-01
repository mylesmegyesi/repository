require 'time'
require 'repository/cursor'

module Repository
  class Base

    def create!(model_or_hash={})
      attrs = model_or_hash_as_attrs(model_or_hash)
      model = model_klass.new(attrs.merge(created_at: Time.now.utc, updated_at: Time.now.utc))
      find_by_id(store_record!(model.to_h))
    end

    def update!(model, attrs={})
      old_model = find_by_id(model.id)
      raise ArgumentError.new("Could not update record with id: #{model.id} because it does not exist") unless old_model
      clean_attrs = (attrs || {}).reject {|k, v| blacklist_update_attrs.include?(k)}
      updated_attrs = old_model.to_h.merge(model.to_h).merge(clean_attrs).merge(updated_at: Time.now.utc)
      new_model = model_klass.new(updated_attrs)
      new_model.id = model.id
      store_record!(new_model.to_h)
      find_by_id(model.id)
    end

    def remove_by_id!(id)
      if model = find_by_id(id)
        remove_model!(model)
      else
        raise ArgumentError.new("Could not remove record with id: #{id} because it does not exist")
      end
    end

    def remove!(model=nil)
      if model
        remove_by_id!(model.id)
      else
        cursor.remove!
      end
    end

    def all
      cursor.all
    end

    def first
      cursor.first
    end

    def last
      cursor.last
    end

    def eq(field, value)
      cursor.eq(field, value)
    end

    def not_eq(field, value)
      cursor.not_eq(field, value)
    end

    def lt(field, value)
      cursor.lt(field, value)
    end

    def lte(field, value)
      cursor.lte(field, value)
    end

    def gt(field, value)
      cursor.gt(field, value)
    end

    def gte(field, value)
      cursor.gte(field, value)
    end

    def in(field, value)
      cursor.in(field, value)
    end

    def not_in(field, value)
      cursor.not_in(field, value)
    end

    def count
      cursor.count
    end

    def sort(field, value)
      cursor.sort(field, value)
    end

    private

    attr_reader :model_klass

    def cursor
      Cursor.new(self)
    end

    def blacklist_update_attrs
      [:id]
    end

    def model_or_hash_as_attrs(model_or_hash)
      if model_or_hash
        if model_or_hash.is_a?(Hash)
          model_or_hash
        elsif model_or_hash.is_a?(model_klass)
          model_or_hash.to_h
        else
          raise ArgumentError.new("A hash or a #{model_klass} must be given to create a record")
        end
      else
        {}
      end
    end

  end
end
