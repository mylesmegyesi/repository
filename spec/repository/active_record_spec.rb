require 'database_cleaner'
require 'repository/active_record'
require 'memory_user'
require 'repository_examples'

class ARUser < ActiveRecord::Base
  self.table_name = 'users'

  def ==(other)
    self.attributes == other.attributes
  end
end

describe Repository::ActiveRecord do

  before :all do
    #require 'logger'
    #ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Base.establish_connection 'sqlite3:///test.sqlite3'
    DatabaseCleaner[:active_record].strategy = :truncation
    ActiveRecord::Migration.verbose = false
    migration_dir = File.expand_path(File.join('..', '..', 'migrations'), __FILE__)
    ActiveRecord::Migrator.migrate(migration_dir)
  end

  before :each do
    DatabaseCleaner.start
  end

  after :each do
    DatabaseCleaner.clean
  end

  it_behaves_like 'repository', ARUser, MemoryUser, {domain_model_klass: MemoryUser}
  it_behaves_like 'repository', ARUser, ARUser, {}
end


