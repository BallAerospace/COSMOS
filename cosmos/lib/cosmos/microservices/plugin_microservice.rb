# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'cosmos/microservices/microservice'
require 'cosmos/topics/topic'
require 'cosmos/utilities/s3'

module Cosmos

  class PluginMicroservice < Microservice

    def initialize(name)
      super(name, is_plugin: true)

      # TODO: actually this will be done in microservice.rb
      # # TODO: check if we need to do this first (don't for built-in microservices)
      # # download code from minio
      # rubys3_client = initialize_bucket()
      # temp_dir = Dir.mktmpdir
      # @path = File.join(temp_dir, name)
      # rubys3_client.get_object(bucket: 'gems', key: name, response_target: @path)
    end

    def run
      Dir.chdir @config["work_dir"]
      exec(*@config["cmd"])
    end

    # # private
    # def self.initialize_bucket
    #   rubys3_client = Aws::S3::Client.new
    #   unless @@bucket_initialized
    #     begin
    #       rubys3_client.head_bucket(bucket: 'gems')
    #     rescue Aws::S3::Errors::NotFound
    #       rubys3_client.create_bucket(bucket: 'gems')
    #     end
    #     @@bucket_initialized = true
    #   end
    #   return rubys3_client
    # end

  end
end

Cosmos::PluginMicroservice.run if __FILE__ == $0
