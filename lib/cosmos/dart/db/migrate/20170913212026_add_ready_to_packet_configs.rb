class AddReadyToPacketConfigs < ActiveRecord::Migration[5.0]
  def change
    add_column :packet_configs, :ready, :boolean, :default => false
  end
end
