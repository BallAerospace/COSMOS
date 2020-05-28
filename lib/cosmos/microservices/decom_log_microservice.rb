# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/microservices/microservice'

module Cosmos
  class DecomLogMicroservice < Microservice
    def run
      kafka_consumer_loop do |message|
        begin
          # TODO
          break if @cancel_thread
        rescue => err
          Logger.error("DecomLog error: #{err.formatted}")
        end
      end
    end
  end
end

Cosmos::DecomLogMicroservice.run if __FILE__ == $0
