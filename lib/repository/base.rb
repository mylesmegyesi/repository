require 'time'
require 'repository/cursor'
require 'repository/filter_factory'

module Repository
  class Base

    def find
      cursor
    end

    def filter
      @filter_factory ||= FilterFactory.new
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
        remove_by_id!(model.send(primary_key))
      else
        cursor.remove!
      end
    end

    private

    attr_reader :model_klass

    def cursor
      Cursor.new(self)
    end

    def model_or_hash_as_attrs(model_or_hash)
      if model_or_hash
        if model_or_hash.is_a?(Hash)
          model_or_hash
        elsif model_or_hash.is_a?(model_klass)
          model_or_hash.attributes
        else
          raise ArgumentError.new("A hash or a #{model_klass} must be given to create a record")
        end
      else
        {}
      end
    end

  end
end
