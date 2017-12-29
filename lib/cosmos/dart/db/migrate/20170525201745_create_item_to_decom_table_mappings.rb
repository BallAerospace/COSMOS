class CreateItemToDecomTableMappings < ActiveRecord::Migration[5.0]
  def change
    create_table :item_to_decom_table_mappings do |t|
      t.integer :target_id, :null => false
      t.integer :packet_id, :null => false
      t.integer :item_id, :null => false
      t.integer :decom_table_id, :null => false

      t.timestamps
    end
  end
end
