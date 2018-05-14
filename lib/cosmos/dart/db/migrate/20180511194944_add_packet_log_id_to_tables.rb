class AddPacketLogIdToTables < ActiveRecord::Migration[5.1]
  def change
    ActiveRecord::Base.connection.tables.each do |table|
      # Since the decommutation tables are created dynamically we search
      # through all the tables looking for tables named something like
      # tXXX_YYY where XXX is the PacketConfig ID and YYY is the table index
      if table.to_s =~ /^t(\d+)_(\d+)$/ # ASCII art? No! Regex!
        packet_config_id = $1.to_i
        table_index = $2.to_i

        ["", "_m", "_h", "_d"].each do |modifier|
          table_name = table + modifier
          add_column table_name, :packet_log_id, :integer
        end
      end
    end
  end
end
