class AddMetaIdToPacketLogEntries < ActiveRecord::Migration[5.0]
  def change
    add_column :packet_log_entries, :meta_id, :bigint
    add_index(:packet_log_entries, :meta_id)
  end
end
