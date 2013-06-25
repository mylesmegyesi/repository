# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.name          = "repositories"
  gem.version       = '0.0.1'
  gem.authors       = ["Myles Megyesi"]
  gem.email         = ["myles.megyesi@gmail.com"]
  gem.description   = 'Repository?'
  gem.summary       = 'Store some data?'

  gem.files           = Dir['lib/**/*.rb']
  gem.require_paths = ["lib"]

  gem.add_development_dependency 'activerecord',     '~> 3.2.11'
  gem.add_development_dependency 'bson_ext',         '~> 1.8.6'
  gem.add_development_dependency 'database_cleaner', '~> 0.9.1'
  gem.add_development_dependency 'mongo',            '~> 1.8.1'
  gem.add_development_dependency 'multi_json',       '~> 1.5.0'
  gem.add_development_dependency 'rake',             '~> 10.0.3'
  gem.add_development_dependency 'rspec',            '~> 2.12.0'
  gem.add_development_dependency 'sqlite3',          '~> 1.3.6'
  gem.add_development_dependency 'virtus',           '~> 0.5.3'
end
