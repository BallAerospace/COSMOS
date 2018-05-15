class AddDecomStateIndex < ActiveRecord::Migration[5.1]
  def change
    add_index :packet_log_entries, [:decom_state]
  end
end
