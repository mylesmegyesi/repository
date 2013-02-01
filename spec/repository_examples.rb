require 'time'

SECONDS_IN_DAY = 24 * 60 * 60

shared_examples_for 'repository' do |model_klass, repo_options|
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
      created_record.to_h.should == found.to_h
    end

    it 'creates a record an empty record when nil is given' do
      created_record = repo.create!(nil)
      found = repo.find_by_id(created_record.id)
      created_record.to_h.should == found.to_h
    end

    it 'creates a record with a hash of attribtues' do
      created_record = repo.create!(name: 'John')
      created_record.name.should == 'John'
      found = repo.find_by_id(created_record.id)
      created_record.to_h.should == found.to_h
    end

    it 'creates a record with a model' do
      model = model_klass.new(name: 'John')
      created_record = repo.create!(model)
      created_record.name.should == 'John'
      found = repo.find_by_id(created_record.id)
      created_record.to_h.should == found.to_h
    end

    it 'assigns created_at and updated_at' do
      created_at = Time.parse('11/1/2012 12:00pm UTC')
      created_record = with_time(created_at) {repo.create!}
      created_record.created_at.should == created_at
      created_record.updated_at.should == created_at
    end

    it 'raises an error when a model or hash is not given' do
      expect {repo.create!(double)}.to raise_error(ArgumentError, "A hash or a #{model_klass} must be given to create a record")
    end

  end

  context 'update!' do

    it 'updates a record with attrs' do
      created_record = repo.create!(name: 'John')
      updated_record = repo.update!(created_record, name: 'Steve')
      created_record.should_not == updated_record
      updated_record.name.should == 'Steve'
      repo.find_by_id(updated_record.id).to_h.should == updated_record.to_h
    end

    it 'updates a record with nil attrs' do
      created_record = repo.create!(name: 'John')
      updated_record = repo.update!(created_record, nil)
      updated_record.name.should == 'John'
      repo.find_by_id(updated_record.id).to_h.should == updated_record.to_h
    end

    it 'updates a record with the model' do
      created_record = repo.create!(name: 'John')
      created_record.name = 'Steve'
      updated_record = repo.update!(created_record)
      created_record.should_not == updated_record
      updated_record.name.should == 'Steve'
      repo.find_by_id(updated_record.id).to_h.should == updated_record.to_h
    end

    it 'ignores updates to the id' do
      created_at = Time.parse('11/1/2012 12:00pm UTC')
      created_record = with_time(created_at) {repo.create!}
      updated_record = with_time(created_at) {repo.update!(created_record, id: :something_else)}
      updated_record.to_h.should == created_record.to_h
      repo.find_by_id(updated_record.id).to_h.should == updated_record.to_h
    end

    it 'assigns updated at' do
      created_at = Time.parse('11/1/2012 12:00pm UTC')
      updated_at = Time.parse('11/2/2012 12:00pm UTC')
      created_record = with_time(created_at) {repo.create!}
      updated_record = with_time(updated_at) {repo.update!(created_record)}
      found = repo.find_by_id(updated_record.id)
      found.to_h.should == updated_record.to_h
      found.created_at.should == created_at
      found.updated_at.should == updated_at
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
      repo.find_by_id(created_record2.id).to_h.should == created_record2.to_h
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
      repo.find_by_id(created_record2.id).to_h.should == created_record2.to_h
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
      repo.all.should be_empty
    end

    it 'filters all records' do
      record1 = repo.create!(name: 'Steve')
      record2 = repo.create!(name: 'John')
      repo.all.map(&:to_h).should =~ [record1.to_h, record2.to_h]
      repo.count.should == 2
      repo.remove!
      repo.all.should be_empty
    end

    it 'filters on equality' do
      record1 = repo.create!(name: 'Steve')
      record2 = repo.create!(name: 'John')
      repo.eq(:name, 'Steve').all.map(&:to_h).should == [record1.to_h]
      repo.eq(:name, 'Steve').count.should == 1
      repo.eq(:name, 'John').all.map(&:to_h).should == [record2.to_h]
      repo.eq(:name, 'John').count.should == 1
      repo.eq(:name, 'John').remove!
      repo.eq(:name, 'John').count.should == 0
    end

    it 'filters on nil equality' do
      record1 = repo.create!(name: nil)
      record2 = repo.create!(name: 'John')
      repo.eq(:name, nil).all.map(&:to_h).should == [record1.to_h]
      repo.eq(:name, nil).count.should == 1
      repo.eq(:name, 'John').all.map(&:to_h).should == [record2.to_h]
      repo.eq(:name, 'John').count.should == 1
    end

    it 'equality filter raises an error for a bad field name' do
      field = mock
      expect {repo.eq(field, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(field, '')}")
      expect {repo.eq(nil, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(nil, '')}")
    end

    it 'filters on inequality' do
      record1 = repo.create!(name: 'Steve')
      record2 = repo.create!(name: 'John')
      repo.not_eq(:name, 'Steve').all.map(&:to_h).should == [record2.to_h]
      repo.not_eq(:name, 'Steve').count.should == 1
      repo.not_eq(:name, 'John').all.map(&:to_h).should == [record1.to_h]
      repo.not_eq(:name, 'John').count.should == 1
      repo.not_eq(:name, 'John').remove!
      repo.not_eq(:name, 'John').count.should == 0
    end

    it 'filters on nil inequality' do
      record1 = repo.create!(name: nil)
      record2 = repo.create!(name: 'John')
      repo.not_eq(:name, nil).all.map(&:to_h).should == [record2.to_h]
      repo.not_eq(:name, nil).count.should == 1
      repo.not_eq(:name, 'John').all.map(&:to_h).should == [record1.to_h]
      repo.not_eq(:name, 'John').count.should == 1
    end

    it 'inequality filter raises an error for a bad field name' do
      field = mock
      expect {repo.not_eq(field, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(field, '')}")
      expect {repo.not_eq(nil, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(nil, '')}")
    end

    it 'filters on less than' do
      record1 = repo.create!(age: 18)
      record2 = repo.create!(age: 25)
      repo.lt(:age, 18).all.should == []
      repo.lt(:age, 18).count.should == 0
      repo.lt(:age, 19).all.map(&:to_h).should == [record1.to_h]
      repo.lt(:age, 19).count.should == 1
      repo.lt(:age, 25).all.map(&:to_h).should == [record1.to_h]
      repo.lt(:age, 25).count.should == 1
      repo.lt(:age, 26).all.map(&:to_h).should =~ [record1.to_h, record2.to_h]
      repo.lt(:age, 26).count.should == 2
      repo.lt(:age, 26).remove!
      repo.lt(:age, 26).count.should == 0
    end

    it 'filters on nil less than' do
      record1 = repo.create!(age: nil)
      record2 = repo.create!(age: 18)
      repo.lt(:age, 19).all.map(&:to_h).should == [record2.to_h]
      expect {repo.lt(:age, nil)}.to \
        raise_error(ArgumentError, "Less than filter value cannot be nil")
    end

    it 'less than filter raises an error for a bad field name' do
      field = mock
      expect {repo.lt(field, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(field, '')}")
      expect {repo.lt(nil, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(nil, '')}")
    end

    it 'filters on less than or equal to' do
      record1 = repo.create!(age: 18)
      record2 = repo.create!(age: 25)
      repo.lte(:age, 17).all.map(&:to_h).should be_empty
      repo.lte(:age, 17).count.should == 0
      repo.lte(:age, 18).all.map(&:to_h).should == [record1.to_h]
      repo.lte(:age, 19).all.map(&:to_h).should == [record1.to_h]
      repo.lte(:age, 19).count.should == 1
      repo.lte(:age, 25).all.map(&:to_h).should =~ [record1.to_h, record2.to_h]
      repo.lte(:age, 26).all.map(&:to_h).should =~ [record1.to_h, record2.to_h]
      repo.lte(:age, 26).count.should == 2
      repo.lte(:age, 26).remove!
      repo.lte(:age, 26).count.should == 0
    end

    it 'filters on nil less than or equal to' do
      record1 = repo.create!(age: nil)
      record2 = repo.create!(age: 18)
      repo.lte(:age, 18).all.map(&:to_h).should == [record2.to_h]
      expect {repo.lte(:age, nil)}.to \
        raise_error(ArgumentError, "Less than or equal to filter value cannot be nil")
    end

    it 'less than or equal to filter raises an error for a bad field name' do
      field = mock
      expect {repo.lte(field, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(field, '')}")
      expect {repo.lte(nil, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(nil, '')}")
    end

    it 'filters on greater than' do
      record1 = repo.create!(age: 18)
      record2 = repo.create!(age: 25)
      repo.gt(:age, 25).all.map(&:to_h).should be_empty
      repo.gt(:age, 25).count.should == 0
      repo.gt(:age, 24).all.map(&:to_h).should == [record2.to_h]
      repo.gt(:age, 18).all.map(&:to_h).should == [record2.to_h]
      repo.gt(:age, 18).count.should == 1
      repo.gt(:age, 17).all.map(&:to_h).should =~ [record1.to_h, record2.to_h]
      repo.gt(:age, 17).count.should == 2
      repo.gt(:age, 17).remove!
      repo.gt(:age, 17).count.should == 0
    end

    it 'filters on nil greater than' do
      record1 = repo.create!(age: nil)
      record2 = repo.create!(age: 18)
      repo.gt(:age, 17).all.map(&:to_h).should == [record2.to_h]
      expect {repo.gt(:age, nil)}.to \
        raise_error(ArgumentError, "Greater than filter value cannot be nil")
    end

    it 'greater than filter raises an error for a bad field name' do
      field = mock
      expect {repo.gt(field, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(field, '')}")
      expect {repo.gt(nil, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(nil, '')}")
    end

    it 'filters on greater than or equal to' do
      record1 = repo.create!(age: 18)
      record2 = repo.create!(age: 25)
      repo.gte(:age, 26).all.map(&:to_h).should be_empty
      repo.gte(:age, 26).count.should == 0
      repo.gte(:age, 25).all.map(&:to_h).should == [record2.to_h]
      repo.gte(:age, 25).count.should == 1
      repo.gte(:age, 18).all.map(&:to_h).should =~ [record1.to_h, record2.to_h]
      repo.gte(:age, 18).count.should == 2
      repo.gte(:age, 18).remove!
      repo.gte(:age, 18).count.should == 0
    end

    it 'filters on nil greater than or equal to' do
      record1 = repo.create!(age: nil)
      record2 = repo.create!(age: 18)
      repo.gte(:age, 18).all.map(&:to_h).should == [record2.to_h]
      expect {repo.gte(:age, nil)}.to \
        raise_error(ArgumentError, "Greater than or equal to filter value cannot be nil")
    end

    it 'greater than or equal to filter raises an error for a bad field name' do
      field = mock
      expect {repo.gte(field, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(field, '')}")
      expect {repo.gte(nil, 'Steve')}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(nil, '')}")
    end

    it 'filters on inclusion' do
      record1 = repo.create!(age: 18)
      record2 = repo.create!(age: 25)
      repo.in(:age, []).all.should be_empty
      repo.in(:age, [30]).all.should be_empty
      repo.in(:age, [18]).all.map(&:to_h).should == [record1.to_h]
      repo.in(:age, [25]).all.map(&:to_h).should == [record2.to_h]
      repo.in(:age, [25]).count.should == 1
      repo.in(:age, [18, 25]).all.map(&:to_h).should =~ [record1.to_h, record2.to_h]
      repo.in(:age, [18, 25, 30]).all.map(&:to_h).should =~ [record1.to_h, record2.to_h]
      repo.in(:age, [18, 25, 30]).count.should == 2
      repo.in(:age, [18, 25, 30]).remove!
      repo.in(:age, [18, 25, 30]).count.should == 0
    end

    it 'filters on nil inclusion' do
      record1 = repo.create!(age: nil)
      record2 = repo.create!(age: 18)
      record3 = repo.create!(name: 'Steve')
      repo.in(:age, [nil]).all.map(&:to_h).should =~ [record1.to_h, record3.to_h]
      repo.in(:age, [nil]).count.should == 2
      repo.in(:age, [18]).all.map(&:to_h).should == [record2.to_h]
      repo.in(:age, [18]).count.should == 1
      repo.in(:age, [nil, 18]).all.map(&:to_h).should =~ [record1.to_h, record2.to_h, record3.to_h]
      repo.in(:age, [nil, 18]).count.should == 3
      repo.in(:name, ['Steve']).all.map(&:to_h).should == [record3.to_h]
    end

    it 'inclusion filter raises an error for a bad field name' do
      field = mock
      expect {repo.in(field, ['Steve'])}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(field, '')}")
      expect {repo.in(nil, ['Steve'])}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(nil, '')}")
    end

    it 'inclusion filter value must respond to to_a' do
      record1 = repo.create!(age: nil)
      record2 = repo.create!(age: 18)
      record3 = repo.create!(name: 'Steve')
      repo.in(:age, (1..20)).all.map(&:to_h).should == [record2.to_h]
      expect {repo.in(:age, 19)}.to \
        raise_error(ArgumentError, "Inclusion filter value must respond to to_a but #{PP.pp(19, '')} does not")
    end

    it 'filters on exclusion' do
      record1 = repo.create!(age: 18)
      record2 = repo.create!(age: 25)
      record3 = repo.create!(name: 'Steve')
      repo.not_in(:age, []).all.map(&:to_h).should =~ [record1.to_h, record2.to_h, record3.to_h]
      repo.not_in(:age, []).count.should == 3
      repo.not_in(:age, [30]).all.map(&:to_h).should =~ [record1.to_h, record2.to_h, record3.to_h]
      repo.not_in(:age, [25]).all.map(&:to_h).should =~ [record1.to_h, record3.to_h]
      repo.not_in(:age, [18]).all.map(&:to_h).should =~ [record2.to_h, record3.to_h]
      repo.not_in(:age, [18]).count.should == 2
      repo.not_in(:age, [18, 25]).all.map(&:to_h).should == [record3.to_h]
      repo.not_in(:age, [18, 25, 30]).not_in(:name, ['Steve']).all.should be_empty
      repo.not_in(:age, [18]).remove!
      repo.not_in(:age, [18]).count.should == 0
    end

    it 'filters on nil exclusion' do
      record1 = repo.create!(age: nil)
      record2 = repo.create!(age: 18)
      record3 = repo.create!(name: 'Steve')
      repo.not_in(:age, [nil]).all.map(&:to_h).should == [record2.to_h]
      repo.not_in(:age, [18]).all.map(&:to_h).should =~ [record1.to_h, record3.to_h]
      repo.not_in(:age, [nil, 18]).all.map(&:to_h).should == []
      repo.not_in(:name, ['Steve']).all.map(&:to_h).should =~ [record1.to_h, record2.to_h]
    end

    it 'exclusion filter raises an error for a bad field name' do
      field = mock
      expect {repo.not_in(field, ['Steve'])}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(field, '')}")
      expect {repo.not_in(nil, ['Steve'])}.to \
        raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(nil, '')}")
    end

    it 'exclusion filter value must respond to to_a' do
      record1 = repo.create!(age: nil)
      record2 = repo.create!(age: 18)
      record3 = repo.create!(name: 'Steve')
      repo.not_in(:age, (1..20)).all.map(&:to_h).should == [record1.to_h, record3.to_h]
      expect {repo.not_in(:age, 19)}.to \
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
      repo.eq(:name, 'Steve').first.to_h.should == record1.to_h
    end

    it 'returns the first created record when no sorts are specified' do
      record1 = with_time(days_ago(10)) {repo.create!(name: 'Steve')}
      record2 = with_time(days_ago(5)) {repo.create!(name: 'John')}
      repo.first.to_h.should == record2.to_h
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
       cursor = repo.sort(:age, :asc).sort(:name, :asc)
       cursor.first.name.should == 'one'
       cursor.last.name.should == 'forty5'
    end

    it 'returns the first created record when no sorts are specified' do
      record1 = with_time(days_ago(5)) {repo.create!(name: 'Steve')}
      record2 = with_time(days_ago(10)) {repo.create!(name: 'John')}
      repo.last.to_h.should == record2.to_h
    end

  end

  it 'sorts records' do
    record1, record2, record3 = records
    repo.sort(:opened_at, :asc).all.map(&:to_h).should == [record1.to_h, record2.to_h, record3.to_h]
    repo.sort(:opened_at, :desc).all.map(&:to_h).should == [record3.to_h, record2.to_h, record1.to_h]
    repo.sort(:opened_at, 'asc').all.map(&:to_h).should == [record1.to_h, record2.to_h, record3.to_h]
    repo.sort(:opened_at, 'desc').all.map(&:to_h).should == [record3.to_h, record2.to_h, record1.to_h]
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
     repo.sort(:age, :asc).sort(:name, :asc).all.map(&:name).should == ['one', 'the one', 'twelve', 'twenty3', 'thirty4', 'forty4', 'forty5']
  end

  it 'sort raises an error for a bad field name' do
    field = mock
    expect {repo.sort(field, :asc)}.to \
      raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(field, '')}")
    expect {repo.sort(nil, :asc)}.to \
      raise_error(ArgumentError, "Field name must be a String or Symbol but you gave #{PP.pp(nil, '')}")
  end

  it 'sort raises an error for a bad order' do
    expect {repo.sort(:name, :whoops)}.to \
      raise_error(ArgumentError, "Sort order must be 'asc' or 'desc' but you gave #{PP.pp(:whoops, '')}")
  end

  it 'limits' do
    record1, record2, record3 = records
    repo.sort(:opened_at, :asc).limit(1).all.map(&:to_h).should == [record1.to_h]
    repo.sort(:opened_at, :asc).limit('1').all.map(&:to_h).should == [record1.to_h]
    repo.sort(:opened_at, :asc).limit(nil).all.map(&:to_h).should == [record1.to_h, record2.to_h, record3.to_h]
    repo.sort(:opened_at, :desc).limit(1).all.map(&:to_h).should == [record3.to_h]
  end

  it 'limit raises an error if not an integer' do
    limit = mock
    expect {repo.sort(:name, :asc).limit(limit)}.to \
      raise_error(ArgumentError, "Limit must be an integer but you gave #{PP.pp(limit, '')}")
  end

  it 'offsets' do
    record1, record2, record3 = records
    repo.sort(:opened_at, :asc).offset(1).all.map(&:to_h).should == [record2.to_h, record3.to_h]
    repo.sort(:opened_at, :asc).offset('1').all.map(&:to_h).should == [record2.to_h, record3.to_h]
    repo.sort(:opened_at, :asc).offset(nil).all.map(&:to_h).should == [record1.to_h, record2.to_h, record3.to_h]
    repo.sort(:opened_at, :desc).offset(1).all.map(&:to_h).should == [record2.to_h, record1.to_h]
  end

  it 'offset raises an error if not an integer' do
    offset = mock
    expect {repo.sort(:name, :asc).offset(offset)}.to \
      raise_error(ArgumentError, "Offset must be an integer but you gave #{PP.pp(offset, '')}")
  end

  it 'limits and offsets' do
    record1, record2, record3 = records
    repo.sort(:opened_at, :asc).offset(1).limit(1).all.map(&:to_h).should == [record2.to_h]
    repo.sort(:opened_at, :desc).offset(1).limit(1).all.map(&:to_h).should == [record2.to_h]
  end

  it 'finds records with a open date greater than yesterday' do
    now       = imprecise_time
    yesterday = imprecise_time(days_ago(1))

    record1 = repo.create!(opened_at: yesterday)
    record2 = repo.create!(opened_at: now)

    records = repo.gt(:opened_at, yesterday)
    records.count.should == 1
    records.first.to_h.should == record2.to_h
  end

  it 'finds records with a close date greater or equal to yesterday' do
    now       = imprecise_time
    yesterday = imprecise_time(days_ago(1))

    record1 = repo.create!(opened_at: yesterday)
    record2 = repo.create!(opened_at: now)

    records = repo.gte(:opened_at, yesterday)
    records.all.map(&:to_h).should =~ [record1.to_h, record2.to_h]
    records.count.should == 2
  end

  it 'finds records with a close date less than today' do
    record1 = repo.create!(opened_at: imprecise_time(days_ago(2)))
    record2 = repo.create!(opened_at: imprecise_time(Time.now.utc))

    records = repo.lt(:opened_at, imprecise_time(days_ago(1)))
    records.all.map(&:to_h).should == [record1.to_h]
    records.count.should == 1
  end
end

