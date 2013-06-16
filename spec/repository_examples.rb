require 'time'

class Time

  old_eq = instance_method(:==)

  define_method(:==) do |other|
    old_eq.bind(Time.parse(self.to_s)).(Time.parse(other.to_s))
  end

end

SECONDS_IN_DAY = 24 * 60 * 60

shared_examples_for 'repository' do |model_klass, domain_model_klass, repo_options|
  let(:repo) { described_class.new(model_klass, repo_options) }

  def imprecise_time(time=Time.now.utc)
    Time.parse(time.to_s)
  end

  def with_time(time, &block)
    Time.stub(now: time)
    result = block.call
    Time.unstub!(:now)
    result
  end

  context 'create!' do

    it 'creates a record an empty record' do
      created_record = repo.create!
      found = repo.find_by_id(created_record.id)
      created_record.should == found
    end

    it 'does not create with unknown attributes' do
      expect { repo.create!(unknown: 'here') }.to raise_error
    end

    it 'returns an instance of the domain model' do
      created_record = repo.create!
      created_record.should be_a(domain_model_klass)
    end

    it 'creates a record an empty record when nil is given' do
      created_record = repo.create!(nil)
      found = repo.find_by_id(created_record.id)
      created_record.should == found
    end

    it 'creates a record with a hash of attribtues' do
      created_record = repo.create!(name: 'John')
      created_record.name.should == 'John'
      found = repo.find_by_id(created_record.id)
      created_record.should == found
    end

    it 'creates a record with a model' do
      model = model_klass.new(name: 'John')
      created_record = repo.create!(model)
      created_record.name.should == 'John'
      found = repo.find_by_id(created_record.id)
      created_record.should == found
    end

    it 'raises an error when a model or hash is not given' do
      expect {repo.create!(double)}.to raise_error(ArgumentError, "A hash or a #{model_klass} must be given to create a record")
    end

  end

  context 'update!' do

    it 'updates a record with attrs' do
      created_record = repo.create!(name: 'John')
      updated_record = repo.update!(created_record, name: 'Steve')
      updated_record.name.should == 'Steve'
      repo.find_by_id(updated_record.id).should == updated_record
    end

    it 'returns an instance of the domain model' do
      created_record = repo.create!(name: 'John')
      updated_record = repo.update!(created_record, name: 'Steve')
      updated_record.should be_a(domain_model_klass)
    end

    it 'updates a record with nil attrs' do
      created_record = repo.create!(name: 'John')
      created_record.name = 'Steven'
      updated_record = repo.update!(created_record, nil)
      updated_record.name.should == 'Steven'
      repo.find_by_id(updated_record.id).should == updated_record
    end

    it 'updates a record with the model' do
      created_record = repo.create!(name: 'John')
      created_record.name = 'Steve'
      updated_record = repo.update!(created_record)
      updated_record.name.should == 'Steve'
      repo.find_by_id(updated_record.id).should == updated_record
    end

    it 'ignores updates to the id' do
      created_record = repo.create!
      updated_record = repo.update!(created_record, id: :something_else, name: 'John')
      updated_record.name.should == 'John'
      repo.find_by_id(updated_record.id).should == updated_record
    end

    it 'raises an exception if the record does not exist' do
      record = model_klass.new(name: 'Sally')
      record.id = 1
      expect {repo.update!(record)}.to raise_error(ArgumentError, 'Could not update record with id: 1 because it does not exist')
    end
  end

  context 'remove!' do
    it 'removes the record' do
      created_record1 = repo.create!
      created_record2 = repo.create!
      repo.remove!(created_record1)
      repo.find_by_id(created_record1.id).should be_nil
      repo.find_by_id(created_record2.id).should == created_record2
    end

    it 'raises an exception if the record does not exist' do
      record = model_klass.new(name: 'Sally')
      record.id = 1
      expect {repo.remove!(record)}.to raise_error(ArgumentError, 'Could not remove record with id: 1 because it does not exist')
    end
  end

  context 'remove_by_id!' do
    it 'removes the record' do
      created_record1 = repo.create!
      created_record2 = repo.create!
      repo.remove_by_id!(created_record1.id)
      repo.find_by_id(created_record1.id).should be_nil
      repo.find_by_id(created_record2.id).should == created_record2
    end

    it 'raises an exception if the record does not exist' do
      expect {repo.remove_by_id!(1)}.to raise_error(ArgumentError, 'Could not remove record with id: 1 because it does not exist')
    end
  end

  context 'find_by_id' do
    it 'returns nil if the record does not exist' do
      repo.find_by_id('unknown').should be_nil
    end
  end

  context 'filtering' do

    it 'returns an empty array if there are no records' do
      repo.find.all.should be_empty
    end

    it 'filters all records' do
      record1 = repo.create!(name: 'Steve')
      record2 = repo.create!(name: 'John')
      repo.find.all.should =~ [record1, record2]
      repo.find.count.should == 2
      repo.remove!
      repo.find.all.should be_empty
    end

    it 'returns instances of the domain model' do
      record1 = repo.create!(name: 'Steve')
      record2 = repo.create!(name: 'John')
      repo.find.all.should =~ [record1, record2]
      repo.find.count.should == 2
      repo.remove!
      repo.find.all.each do |record|
        record.should be_a(domain_model_klass)
      end
    end

    it 'filters on equality' do
      record1 = repo.create!(name: 'Steve')
      record2 = repo.create!(name: 'John')
      repo.find.eq(:name, 'Steve').all.should == [record1]
      repo.find.eq(:name, 'Steve').count.should == 1
      repo.find.eq(:name, 'John').all.should == [record2]
      repo.find.eq(:name, 'John').count.should == 1
      repo.find.eq(:name, 'John').remove!
      repo.find.eq(:name, 'John').count.should == 0
    end

    it 'filters on nil equality' do
      record1 = repo.create!(name: nil)
      record2 = repo.create!(name: 'John')
      repo.find.eq(:name, nil).all.should == [record1]
      repo.find.eq(:name, nil).count.should == 1
      repo.find.eq(:name, 'John').all.should == [record2]
      repo.find.eq(:name, 'John').count.should == 1
    end

    it 'equality filter raises an error for a bad field name' do
      field = mock
      expect {repo.find.eq(field, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(field, '')}")
      expect {repo.find.eq(nil, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(nil, '')}")
    end

    it 'filters on inequality' do
      record1 = repo.create!(name: 'Steve')
      record2 = repo.create!(name: 'John')
      repo.find.not_eq(:name, 'Steve').all.should == [record2]
      repo.find.not_eq(:name, 'Steve').count.should == 1
      repo.find.not_eq(:name, 'John').all.should == [record1]
      repo.find.not_eq(:name, 'John').count.should == 1
      repo.find.not_eq(:name, 'John').remove!
      repo.find.not_eq(:name, 'John').count.should == 0
    end

    it 'filters on nil inequality' do
      record1 = repo.create!(name: nil)
      record2 = repo.create!(name: 'John')
      repo.find.not_eq(:name, nil).all.should == [record2]
      repo.find.not_eq(:name, nil).count.should == 1
      repo.find.not_eq(:name, 'John').all.should == [record1]
      repo.find.not_eq(:name, 'John').count.should == 1
    end

    it 'inequality filter raises an error for a bad field name' do
      field = mock
      expect {repo.find.not_eq(field, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(field, '')}")
      expect {repo.find.not_eq(nil, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(nil, '')}")
    end

    it 'filters on less than' do
      record1 = repo.create!(age: 18)
      record2 = repo.create!(age: 25)
      repo.find.lt(:age, 18).all.should == []
      repo.find.lt(:age, 18).count.should == 0
      repo.find.lt(:age, 19).all.should == [record1]
      repo.find.lt(:age, 19).count.should == 1
      repo.find.lt(:age, 25).all.should == [record1]
      repo.find.lt(:age, 25).count.should == 1
      repo.find.lt(:age, 26).all.should =~ [record1, record2]
      repo.find.lt(:age, 26).count.should == 2
      repo.find.lt(:age, 26).remove!
      repo.find.lt(:age, 26).count.should == 0
    end

    it 'filters on nil less than' do
      record1 = repo.create!(age: nil)
      record2 = repo.create!(age: 18)
      repo.find.lt(:age, 19).all.should == [record2]
      expect {repo.find.lt(:age, nil)}.to \
        raise_error(ArgumentError, "Less than filter value cannot be nil")
    end

    it 'less than filter raises an error for a bad field name' do
      field = mock
      expect {repo.find.lt(field, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(field, '')}")
      expect {repo.find.lt(nil, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(nil, '')}")
    end

    it 'filters on less than or equal to' do
      record1 = repo.create!(age: 18)
      record2 = repo.create!(age: 25)
      repo.find.lte(:age, 17).all.should be_empty
      repo.find.lte(:age, 17).count.should == 0
      repo.find.lte(:age, 18).all.should == [record1]
      repo.find.lte(:age, 19).all.should == [record1]
      repo.find.lte(:age, 19).count.should == 1
      repo.find.lte(:age, 25).all.should =~ [record1, record2]
      repo.find.lte(:age, 26).all.should =~ [record1, record2]
      repo.find.lte(:age, 26).count.should == 2
      repo.find.lte(:age, 26).remove!
      repo.find.lte(:age, 26).count.should == 0
    end

    it 'filters on nil less than or equal to' do
      record1 = repo.create!(age: nil)
      record2 = repo.create!(age: 18)
      repo.find.lte(:age, 18).all.should == [record2]
      expect {repo.find.lte(:age, nil)}.to \
        raise_error(ArgumentError, "Less than or equal to filter value cannot be nil")
    end

    it 'less than or equal to filter raises an error for a bad field name' do
      field = mock
      expect {repo.find.lte(field, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(field, '')}")
      expect {repo.find.lte(nil, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(nil, '')}")
    end

    it 'filters on greater than' do
      record1 = repo.create!(age: 18)
      record2 = repo.create!(age: 25)
      repo.find.gt(:age, 25).all.should be_empty
      repo.find.gt(:age, 25).count.should == 0
      repo.find.gt(:age, 24).all.should == [record2]
      repo.find.gt(:age, 18).all.should == [record2]
      repo.find.gt(:age, 18).count.should == 1
      repo.find.gt(:age, 17).all.should =~ [record1, record2]
      repo.find.gt(:age, 17).count.should == 2
      repo.find.gt(:age, 17).remove!
      repo.find.gt(:age, 17).count.should == 0
    end

    it 'filters on nil greater than' do
      record1 = repo.create!(age: nil)
      record2 = repo.create!(age: 18)
      repo.find.gt(:age, 17).all.should == [record2]
      expect {repo.find.gt(:age, nil)}.to \
        raise_error(ArgumentError, "Greater than filter value cannot be nil")
    end

    it 'greater than filter raises an error for a bad field name' do
      field = mock
      expect {repo.find.gt(field, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(field, '')}")
      expect {repo.find.gt(nil, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(nil, '')}")
    end

    it 'filters on greater than or equal to' do
      record1 = repo.create!(age: 18)
      record2 = repo.create!(age: 25)
      repo.find.gte(:age, 26).all.should be_empty
      repo.find.gte(:age, 26).count.should == 0
      repo.find.gte(:age, 25).all.should == [record2]
      repo.find.gte(:age, 25).count.should == 1
      repo.find.gte(:age, 18).all.should =~ [record1, record2]
      repo.find.gte(:age, 18).count.should == 2
      repo.find.gte(:age, 18).remove!
      repo.find.gte(:age, 18).count.should == 0
    end

    it 'filters on nil greater than or equal to' do
      record1 = repo.create!(age: nil)
      record2 = repo.create!(age: 18)
      repo.find.gte(:age, 18).all.should == [record2]
      expect {repo.find.gte(:age, nil)}.to \
        raise_error(ArgumentError, "Greater than or equal to filter value cannot be nil")
    end

    it 'greater than or equal to filter raises an error for a bad field name' do
      field = mock
      expect {repo.find.gte(field, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(field, '')}")
      expect {repo.find.gte(nil, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(nil, '')}")
    end

    it 'filters on inclusion' do
      record1 = repo.create!(age: 18)
      record2 = repo.create!(age: 25)
      repo.find.in(:age, []).all.should be_empty
      repo.find.in(:age, [30]).all.should be_empty
      repo.find.in(:age, [18]).all.should == [record1]
      repo.find.in(:age, [25]).all.should == [record2]
      repo.find.in(:age, [25]).count.should == 1
      repo.find.in(:age, [18, 25]).all.should =~ [record1, record2]
      repo.find.in(:age, [18, 25, 30]).all.should =~ [record1, record2]
      repo.find.in(:age, [18, 25, 30]).count.should == 2
      repo.find.in(:age, [18, 25, 30]).remove!
      repo.find.in(:age, [18, 25, 30]).count.should == 0
    end

    it 'filters on nil inclusion' do
      record1 = repo.create!(age: nil)
      record2 = repo.create!(age: 18)
      record3 = repo.create!(name: 'Steve')
      repo.find.in(:age, [nil]).all.should =~ [record1, record3]
      repo.find.in(:age, [nil]).count.should == 2
      repo.find.in(:age, [18]).all.should == [record2]
      repo.find.in(:age, [18]).count.should == 1
      repo.find.in(:age, [nil, 18]).all.should =~ [record1, record2, record3]
      repo.find.in(:age, [nil, 18]).count.should == 3
      repo.find.in(:name, ['Steve']).all.should == [record3]
    end

    it 'inclusion filter raises an error for a bad field name' do
      field = mock
      expect {repo.find.in(field, ['Steve'])}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(field, '')}")
      expect {repo.find.in(nil, ['Steve'])}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(nil, '')}")
    end

    it 'inclusion filter value must respond to to_a' do
      record1 = repo.create!(age: nil)
      record2 = repo.create!(age: 18)
      record3 = repo.create!(name: 'Steve')
      repo.find.in(:age, (1..20)).all.should == [record2]
      expect {repo.find.in(:age, 19)}.to \
        raise_error(ArgumentError, "Inclusion filter value must respond to to_a but #{PP.pp(19, '')} does not")
    end

    it 'filters on exclusion' do
      record1 = repo.create!(age: 18)
      record2 = repo.create!(age: 25)
      record3 = repo.create!(name: 'Steve')
      repo.find.not_in(:age, []).all.should =~ [record1, record2, record3]
      repo.find.not_in(:age, []).count.should == 3
      repo.find.not_in(:age, [30]).all.should =~ [record1, record2, record3]
      repo.find.not_in(:age, [25]).all.should =~ [record1, record3]
      repo.find.not_in(:age, [18]).all.should =~ [record2, record3]
      repo.find.not_in(:age, [18]).count.should == 2
      repo.find.not_in(:age, [18, 25]).all.should == [record3]
      repo.find.not_in(:age, [18, 25, 30]).not_in(:name, ['Steve']).all.should be_empty
      repo.find.not_in(:age, [18]).remove!
      repo.find.not_in(:age, [18]).count.should == 0
    end

    it 'filters on nil exclusion' do
      record1 = repo.create!(age: nil)
      record2 = repo.create!(age: 18)
      record3 = repo.create!(name: 'Steve')
      repo.find.not_in(:age, [nil]).all.should == [record2]
      repo.find.not_in(:age, [18]).all.should =~ [record1, record3]
      repo.find.not_in(:age, [nil, 18]).all.should == []
      repo.find.not_in(:name, ['Steve']).all.should =~ [record1, record2]
    end

    it 'exclusion filter raises an error for a bad field name' do
      field = mock
      expect {repo.find.not_in(field, ['Steve'])}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(field, '')}")
      expect {repo.find.not_in(nil, ['Steve'])}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(nil, '')}")
    end

    it 'exclusion filter value must respond to to_a' do
      record1 = repo.create!(age: nil)
      record2 = repo.create!(age: 18)
      record3 = repo.create!(name: 'Steve')
      repo.find.not_in(:age, (1..20)).all.should == [record1, record3]
      expect {repo.find.not_in(:age, 19)}.to \
        raise_error(ArgumentError, "Exclusion filter value must respond to to_a but #{PP.pp(19, '')} does not")
    end
  end

  def days_ago(days)
    Time.now.utc - (days * SECONDS_IN_DAY)
  end

  def records
    [
      repo.create!(opened_at: imprecise_time(days_ago(5))),
      repo.create!(opened_at: imprecise_time(days_ago(3))),
      repo.create!(opened_at: imprecise_time(days_ago(1)))
    ]
  end

  context 'first' do

    it 'finds the first record' do
      record1 = repo.create!(name: 'Steve')
      record2 = repo.create!(name: 'John')
      repo.find.eq(:name, 'Steve').sort(:name, :desc).first.should == record1
    end

  end

  context 'last' do

    it 'finds the last record' do
      [{:age => 1,   :name => 'one'   },
       {:age => 12,  :name => 'twelve' },
       {:age => 23,  :name => 'twenty3'},
       {:age => 34,  :name => 'thirty4'},
       {:age => 45,  :name => 'forty5' },
       {:age => 1,   :name => 'the one'},
       {:age => 44,  :name => 'forty4' }].each  do |record|
         repo.create!(record)
       end
       cursor = repo.find.sort(:age, :asc).sort(:name, :asc)
       cursor.first.name.should == 'one'
       cursor.last.name.should == 'forty5'
    end

  end

  it 'sorts records' do
    record1, record2, record3 = records
    repo.find.sort(:opened_at, :asc).all.should == [record1, record2, record3]
    repo.find.sort(:opened_at, :desc).all.should == [record3, record2, record1]
    repo.find.sort(:opened_at, 'asc').all.should == [record1, record2, record3]
    repo.find.sort(:opened_at, 'desc').all.should == [record3, record2, record1]
  end

  it 'sorts with multiple' do
    [{:age => 1,   :name => 'one'   },
     {:age => 12,  :name => 'twelve' },
     {:age => 23,  :name => 'twenty3'},
     {:age => 34,  :name => 'thirty4'},
     {:age => 45,  :name => 'forty5' },
     {:age => 1,   :name => 'the one'},
     {:age => 44,  :name => 'forty4' }].each  do |record|
       repo.create!(record)
     end
     repo.find.sort(:age, :asc).sort(:name, :asc).all.map(&:name).should == ['one', 'the one', 'twelve', 'twenty3', 'thirty4', 'forty4', 'forty5']
  end

  it 'sort raises an error for a bad field name' do
    field = mock
    expect {repo.find.sort(field, :asc)}.to \
      raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(field, '')}")
    expect {repo.find.sort(nil, :asc)}.to \
      raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(nil, '')}")
  end

  it 'sort raises an error for a bad order' do
    expect {repo.find.sort(:name, :whoops)}.to \
      raise_error(ArgumentError, "Sort order must be 'asc' or 'desc' but you gave #{PP.pp(:whoops, '')}")
  end

  it 'limits' do
    record1, record2, record3 = records
    repo.find.sort(:opened_at, :asc).limit(1).all.should == [record1]
    repo.find.sort(:opened_at, :asc).limit('1').all.should == [record1]
    repo.find.sort(:opened_at, :asc).limit(nil).all.should == [record1, record2, record3]
    repo.find.sort(:opened_at, :desc).limit(1).all.should == [record3]
  end

  it 'limit raises an error if not an integer' do
    limit = mock
    expect {repo.find.sort(:name, :asc).limit(limit)}.to \
      raise_error(ArgumentError, "Limit must be an integer but you gave #{PP.pp(limit, '')}")
  end

  it 'offsets' do
    record1, record2, record3 = records
    repo.find.sort(:opened_at, :asc).offset(1).all.should == [record2, record3]
    repo.find.sort(:opened_at, :asc).offset('1').all.should == [record2, record3]
    repo.find.sort(:opened_at, :asc).offset(nil).all.should == [record1, record2, record3]
    repo.find.sort(:opened_at, :desc).offset(1).all.should == [record2, record1]
  end

  it 'offset raises an error if not an integer' do
    offset = mock
    expect {repo.find.sort(:name, :asc).offset(offset)}.to \
      raise_error(ArgumentError, "Offset must be an integer but you gave #{PP.pp(offset, '')}")
  end

  it 'limits and offsets' do
    record1, record2, record3 = records
    repo.find.sort(:opened_at, :asc).offset(1).limit(1).all.should == [record2]
    repo.find.sort(:opened_at, :desc).offset(1).limit(1).all.should == [record2]
  end

  it 'finds records with a open date greater than yesterday' do
    now       = imprecise_time
    yesterday = imprecise_time(days_ago(1))

    record1 = repo.create!(opened_at: yesterday)
    record2 = repo.create!(opened_at: now)

    records = repo.find.gt(:opened_at, yesterday)
    records.count.should == 1
    records.first.should == record2
  end

  it 'finds records with a close date greater or equal to yesterday' do
    now       = imprecise_time
    yesterday = imprecise_time(days_ago(1))

    record1 = repo.create!(opened_at: yesterday)
    record2 = repo.create!(opened_at: now)

    records = repo.find.gte(:opened_at, yesterday)
    records.all.should =~ [record1, record2]
    records.count.should == 2
  end

  it 'finds records with a close date less than today' do
    record1 = repo.create!(opened_at: imprecise_time(days_ago(2)))
    record2 = repo.create!(opened_at: imprecise_time(Time.now.utc))

    records = repo.find.lt(:opened_at, imprecise_time(days_ago(1)))
    records.all.should == [record1]
    records.count.should == 1
  end

  it 'filters on or' do
    record1 = repo.create!(name: 'Steve')
    record2 = repo.create!(name: 'John')
    record3 = repo.create!(name: 'Sally')
    repo.find.all.should =~ [record1, record2, record3]
    repo.find.or(repo.filter.eq(:name, 'Steve'), repo.filter.eq(:name, 'John')).all.should =~ [record1, record2]
  end

  it 'filters on like' do
    record1 = repo.create!(name: 'Steve')
    record2 = repo.create!(name: 'Jolly')
    record3 = repo.create!(name: 'Sally')
    repo.find.all.should =~ [record1, record2, record3]
    repo.find.like(:name, 'eve').all.should == [record1]
    repo.find.like(:name, 'jol').all.should == [record2]
    repo.find.like(:name, 'ly').all.should =~ [record2, record3]
  end

 it 'filters on like with or' do
    record1 = repo.create!(name: 'Steve')
    record2 = repo.create!(name: 'Jolly')
    record3 = repo.create!(name: 'Sally')
    repo.find.all.should =~ [record1, record2, record3]
    repo.find.or(repo.filter.like(:name, 'eve'), repo.filter.like(:name, 'jol')).all.should == [record1, record2]
  end

  it 'like filter raises an error for a bad field name' do
    field = mock
    expect {repo.find.like(field, 'asdf')}.to \
      raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(field, '')}")
    expect {repo.find.like(nil, 'asdf')}.to \
      raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(nil, '')}")
  end

  it 'like filter raises an error for a bad value' do
    field = mock
    expect {repo.find.like(:asdf, field)}.to \
      raise_error(ArgumentError, "Value must be a String or Symbol but you gave #{PP.pp(field, '')}")
    expect {repo.find.like(:asdf, nil)}.to \
      raise_error(ArgumentError, "Value must be a String or Symbol but you gave #{PP.pp(nil, '')}")
  end
end

