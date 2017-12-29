class CreatePackets < ActiveRecord::Migration[5.0]
  def change
    create_table :packets do |t|
      t.integer :target_id, :null => false
      t.string :name, :null => false
      t.boolean :is_tlm, :null => false, :default => true
      t.timestamps
    end
  end
end
