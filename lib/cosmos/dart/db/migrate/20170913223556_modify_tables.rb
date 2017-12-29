class ModifyTables < ActiveRecord::Migration[5.0]
  def change
    drop_table :decom_table_metas
    rename_column :item_to_decom_table_mappings, :decom_table_meta_id, :packet_config_id
    add_column :packet_configs, :start_time, :datetime
    add_column :packet_configs, :end_time, :datetime
    remove_column :packet_configs, :system_config_id
  end
end
