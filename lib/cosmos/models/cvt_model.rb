require 'cosmos/utilities/store'

module Cosmos
  class CvtModel
    def self.set(hash, target_name:, packet_name:, scope:)
      Store.mapped_hmset("#{scope}__tlm__#{target_name}__#{packet_name}", hash)
    end
  end
end