class UdpateDecomTable < ActiveRecord::Migration[5.0]
  def change
    rename_table :decom_tables, :decom_table_metas
    remove_column :decom_table_metas, :reduction
  end
end
