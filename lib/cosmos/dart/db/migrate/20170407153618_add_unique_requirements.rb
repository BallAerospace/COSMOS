class AddUniqueRequirements < ActiveRecord::Migration[5.0]
  def change
    add_index :targets, :name, unique: true
    add_index :packets, [:target_id, :name, :is_tlm], unique: true
    add_index :packet_logs, :filename, unique:true
  end
end
