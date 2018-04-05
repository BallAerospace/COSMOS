class AddIndexForPleReadyToPacketLogEntries < ActiveRecord::Migration[5.1]
  def change
    add_index :packet_log_entries, [:ready]
  end
end
