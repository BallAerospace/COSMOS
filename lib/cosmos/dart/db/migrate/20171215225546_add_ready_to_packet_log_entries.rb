class AddReadyToPacketLogEntries < ActiveRecord::Migration[5.0]
  def change
    add_column :packet_log_entries, :ready, :boolean, :default => false
  end
end
