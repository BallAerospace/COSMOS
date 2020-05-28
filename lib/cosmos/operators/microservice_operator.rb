# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/operators/operator'
require 'redis'

module Cosmos

  class MicroserviceOperator < Operator

    def initialize
      Logger.microservice_name = 'MicroserviceOperator'
      super

      # Get all the microservice configuration from Redis
      redis = Redis.new(url: "redis://localhost:6379/0")
      config = redis.hgetall('cosmos_microservices')
      config.each do |microservice_name, microservice_config|
        microservice_config_parsed = JSON.parse(microservice_config)
        filename = microservice_config_parsed["filename"]
        relative_filename = File.join(__dir__, "../microservices/#{filename}")
        if File.exist?(relative_filename)
          @process_definitions << [@ruby_process_name, relative_filename, microservice_name]
        else
          Logger.error("Microservice #{relative_filename} does not exist")
        end
      end
    end

  end # class

end # module

Cosmos::MicroserviceOperator.run if __FILE__ == $0