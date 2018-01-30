class ItemToDecomTableMapping < ApplicationRecord
  belongs_to :item
  belongs_to :packet_config

  # Value Types
  RAW = 0
  CONVERTED = 1
  RAW_CON = 2
end
