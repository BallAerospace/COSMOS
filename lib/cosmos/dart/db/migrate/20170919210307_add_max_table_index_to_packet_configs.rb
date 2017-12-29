class AddMaxTableIndexToPacketConfigs < ActiveRecord::Migration[5.0]
  def change
    add_column :packet_configs, :max_table_index, :integer, :default => -1
  end
end
