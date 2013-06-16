require 'repository/memory'
require 'memory_user'
require 'repository_examples'

describe Repository::Memory do
  it_behaves_like 'repository', MemoryUser, MemoryUser, {primary_key: :id}
end
