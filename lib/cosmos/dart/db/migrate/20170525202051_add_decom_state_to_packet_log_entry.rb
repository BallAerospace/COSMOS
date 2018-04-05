class AddDecomStateToPacketLogEntry < ActiveRecord::Migration[5.0]
  def change
    add_column :packet_log_entries, :decom_state, :integer, :default => 0
  end
end
