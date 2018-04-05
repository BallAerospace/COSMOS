class CreatePacketConfigs < ActiveRecord::Migration[5.0]
  def change
    create_table :packet_configs do |t|
      t.integer :system_config_id, :null => false
      t.integer :packet_id, :null => false
      t.string :name, :null => false

      t.timestamps
    end
  end
end
