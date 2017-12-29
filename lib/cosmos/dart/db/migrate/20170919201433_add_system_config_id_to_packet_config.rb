class AddSystemConfigIdToPacketConfig < ActiveRecord::Migration[5.0]
  def change
    add_column :packet_configs, :first_system_config_id, :integer, :null => false
    add_index :packet_configs, [:packet_id, :name], unique: true

    # Add other needed unique indexes
    add_index :items, [:packet_id, :name], unique: true
    add_index :system_configs, :name, unique: true
    add_index :item_to_decom_table_mappings, [:item_id, :packet_config_id, :value_type], unique: true, name: "mapping_unique"
  end
end
