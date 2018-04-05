class CreatePacketLogs < ActiveRecord::Migration[5.0]
  def change
    create_table :packet_logs do |t|
      t.text :filename, :null => false
      t.boolean :is_tlm, :null => false, :default => true
      t.timestamps
    end
  end
end
