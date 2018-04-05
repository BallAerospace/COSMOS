class CreateItems < ActiveRecord::Migration[5.0]
  def change
    create_table :items do |t|
      t.string :name, :null => false
      t.integer :type, :null => false

      t.timestamps
    end
  end
end
