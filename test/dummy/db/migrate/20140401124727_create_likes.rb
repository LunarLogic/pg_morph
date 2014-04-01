class CreateLikes < ActiveRecord::Migration
  def change
    create_table :likes do |t|
      t.string :likeable_type
      t.integer :likeable_id

      t.timestamps
    end
  end
end
