require 'database_cleaner'
require 'repository/mongo'
require 'memory_user'
require 'repository_examples'

describe Repository::Mongo do
  def self.mongo_client_db
    @mongo_client_db ||= Mongo::MongoClient.from_uri(
      'mongodb://localhost:27017/repository_test',
      pool_size: 100
    ).db('repository_test')
  end

  before :all do
    DatabaseCleaner[:mongo].strategy = :truncation
    DatabaseCleaner[:mongo].db = self.class.mongo_client_db
  end

  before :each do
    DatabaseCleaner.start
  end

  after :each do
    DatabaseCleaner.clean
  end

  it_behaves_like 'repository', MemoryUser, {collection: mongo_client_db.collection('users')}
end

