class Packet < ApplicationRecord
  belongs_to :target
  has_many :packet_log_entries, dependent: :destroy
end
