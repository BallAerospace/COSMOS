class RemoveTimestampsFromPles < ActiveRecord::Migration[5.1]
  def change
    remove_column :packet_log_entries, :created_at
    remove_column :packet_log_entries, :updated_at
  end
end
