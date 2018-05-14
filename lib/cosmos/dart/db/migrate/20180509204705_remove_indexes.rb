class RemoveIndexes < ActiveRecord::Migration[5.1]

  def change
    remove_index :packet_log_entries, :is_tlm
    remove_index :packet_log_entries, :target_id
    remove_index :packet_log_entries, :meta_id
    remove_index :packet_log_entries, :ready
    remove_index :packet_log_entries, :packet_id
    remove_index :packet_log_entries, :packet_log_id

    ActiveRecord::Base.connection.tables.each do |table|
      # Since the decommutation tables are created dynamically we search
      # through all the tables looking for tables named something like
      # tXXX_YYY where XXX is the PacketConfig ID and YYY is the table index
      if table.to_s =~ /^t(\d+)_(\d+)$/ # ASCII art? No! Regex!
        packet_config_id = $1.to_i
        table_index = $2.to_i

        ["", "_m", "_h", "_d"].each do |modifier|
          table_name = table + modifier
          remove_index table_name, :meta_id
          remove_index table_name, :reduced_id
          remove_index table_name, :reduced_state
          add_index table_name, :reduced_state, :where => "reduced_state < 2"
        end
      end
    end
  end
end
