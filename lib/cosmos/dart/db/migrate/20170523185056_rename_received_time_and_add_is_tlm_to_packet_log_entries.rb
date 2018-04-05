class RenameReceivedTimeAndAddIsTlmToPacketLogEntries < ActiveRecord::Migration[5.0]
  def change
    rename_column :packet_log_entries, :received_time, :time
    add_column :packet_log_entries, :is_tlm, :boolean, :null => false
    add_index(:packet_log_entries, :is_tlm)
  end
end
