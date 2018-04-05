class UpdateItemToDecomTableMapping < ActiveRecord::Migration[5.0]
  def change
    remove_column :item_to_decom_table_mappings, :target_id
    remove_column :item_to_decom_table_mappings, :packet_id
    add_column :item_to_decom_table_mappings, :value_type, :integer
    add_column :item_to_decom_table_mappings, :reduction, :integer
    rename_column :item_to_decom_table_mappings, :decom_table_id, :decom_table_meta_id
    add_column :item_to_decom_table_mappings, :table_index, :integer
    add_column :item_to_decom_table_mappings, :item_index, :integer
  end
end
