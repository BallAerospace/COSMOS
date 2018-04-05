class UpdateItems < ActiveRecord::Migration[5.0]
  def change
    remove_column :items, :type
    add_column :items, :packet_id, :integer
  end
end
