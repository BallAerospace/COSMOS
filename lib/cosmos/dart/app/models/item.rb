class Item < ApplicationRecord
  # Don't make this dependent: :destroy since the only way to
  # figure out the dynamically created decommutation and reduction
  # tables is to use ItemToDecomTableMapping
  has_many :item_to_decom_table_mappings
end
