class PacketLog < ApplicationRecord
  has_many :packet_log_entries, dependent: :destroy
end
