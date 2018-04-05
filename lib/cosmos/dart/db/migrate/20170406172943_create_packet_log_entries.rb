class CreatePacketLogEntries < ActiveRecord::Migration[5.0]
  def change
    create_table :packet_log_entries do |t|
      t.integer :target_id, :null => false
      t.integer :packet_id, :null => false
      t.datetime :received_time, :null => false
      t.integer :packet_log_id, :null => false
      t.integer :data_offset, :null => false, :limit => 8
      t.timestamps
    end
    add_index(:packet_log_entries, :target_id)
    add_index(:packet_log_entries, :packet_id)
    add_index(:packet_log_entries, :received_time)
    add_index(:packet_log_entries, :packet_log_id)
  end
end
