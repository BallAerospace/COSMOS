class ModifyMappingTable < ActiveRecord::Migration[5.0]
  def change
    remove_column :item_to_decom_table_mappings, :reduction
    add_column :item_to_decom_table_mappings, :reduced, :boolean
  end
end
