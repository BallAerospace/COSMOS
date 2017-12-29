class ChangePacketLogEntriesPrimaryKey < ActiveRecord::Migration[5.0]
  def change
    change_column :packet_log_entries, :id, :bigint
  end
end
