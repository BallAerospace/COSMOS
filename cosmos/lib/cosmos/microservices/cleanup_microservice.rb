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
require 'cosmos/utilities/s3'

module Cosmos
  class CleanupMicroservice < Microservice
    def run
      # Update settings from config
      @config['options'].each do |option|
        case option[0].upcase
        when 'SIZE' # Max size to use in S3 in bytes
          @size = option[1].to_i
        when 'DELAY' # Delay between size checks
          @delay = option[1].to_i
        when 'BUCKET' # Which bucket to monitor
          @bucket = option[1]
        when 'PREFIX' # Path into bucket to monitor
          @prefix = option[1]
        else
          Logger.error("Unknown option passed to microservice #{@name}: #{option}")
        end
      end

      raise "Microservice #{@name} not fully configured" unless @size and @delay and @bucket and @prefix

      rubys3_client = Aws::S3::Client.new
      while true
        break if @cancel_thread
        @state = 'GETTING_OBJECTS'
        total_size, oldest_list = S3Utilities.get_total_size_and_oldest_list(@bucket, @prefix)
        delete_items = []
        oldest_list.each do |item|
          break if total_size <= @size
          delete_items << { :key => item.key }
          total_size -= item.size
        end
        if delete_items.length > 0
          @state = 'DELETING_OBJECTS'
          rubys3_client.delete_objects({ bucket: @bucket, delete: { objects: delete_items } } )
        end
        @count += 1
        @state = 'SLEEPING'
        break if @microservice_sleeper.sleep(@delay)
      end
    end
  end
end

Cosmos::CleanupMicroservice.run if __FILE__ == $0
