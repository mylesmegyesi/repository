class CreateUsers < ActiveRecord::Migration
  def change
    create_table(:users) do |t|
      t.string    :name
      t.integer   :age
      t.timestamp :opened_at
      t.timestamps
    end
  end
end

