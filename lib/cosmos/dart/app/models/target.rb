class Target < ApplicationRecord
  has_many :packets, dependent: :destroy
  has_many :packet_log_entries, dependent: :destroy
end
