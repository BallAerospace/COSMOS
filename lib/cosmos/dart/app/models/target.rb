class Target < ApplicationRecord
  has_many :packets
  has_many :packet_log_entries
end
