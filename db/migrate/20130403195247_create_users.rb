class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :userid
      t.string :username
      t.text :status
      t.text :report

      t.timestamps
    end
    add_index :users, :userid, :unique => true
  end
end
