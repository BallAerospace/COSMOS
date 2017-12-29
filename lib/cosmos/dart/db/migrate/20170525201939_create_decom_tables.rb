class CreateDecomTables < ActiveRecord::Migration[5.0]
  def change
    create_table :decom_tables do |t|
      t.integer :packet_config_id, :null => false
      t.datetime :start_time, :null => false
      t.datetime :end_time, :null => false
      t.integer :reduction, :null => false

      t.timestamps
    end
  end
end
