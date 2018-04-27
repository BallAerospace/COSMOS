class CreateStatuses < ActiveRecord::Migration[5.1]
  def change
    create_table :statuses do |t|
      t.bigint :decom_count, :default => 0
      t.bigint :decom_error_count, :default => 0
      t.text :decom_message, :default => ""
      t.datetime :decom_message_time

      t.bigint :reduction_count, :default => 0
      t.bigint :reduction_error_count, :default => 0
      t.text :reduction_message, :default => ""
      t.datetime :reduction_message_time

      t.timestamps
    end
    status = Status.new
    time = Time.utc(1970, 1, 1)
    status.decom_message_time = time
    status.reduction_message_time = time
    status.save!
  end
end
