# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
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

require 'cosmos/models/target_model'
require 'cosmos/microservices/microservice'
require 'cosmos/utilities/s3'

module Cosmos
  class CleanupMicroservice < Microservice
    def run
      split_name = @name.split("__")
      target_name = split_name[-1]
      target = TargetModel.get_model(name: target_name, scope: @scope)

      rubys3_client = Aws::S3::Client.new
      while true
        break if @cancel_thread

        @state = 'GETTING_OBJECTS'
        start_time = Time.now
        [
         ["#{@scope}/raw_logs/cmd/#{target_name}/", target.cmd_log_retain_time], 
         ["#{@scope}/decom_logs/cmd/#{target_name}/", target.cmd_decom_log_retain_time], 
         ["#{@scope}/raw_logs/tlm/#{target_name}/", target.tlm_log_retain_time], 
         ["#{@scope}/decom_logs/tlm/#{target_name}/", target.tlm_decom_log_retain_time],
         ["#{@scope}/reduced_minute_logs/tlm/#{target_name}/", target.reduced_minute_log_retain_time],
         ["#{@scope}/reduced_hour_logs/tlm/#{target_name}/", target.reduced_hour_log_retain_time],
         ["#{@scope}/reduced_day_logs/tlm/#{target_name}/", target.reduced_day_log_retain_time],
        ].each do |prefix, retain_time|
          next unless retain_time
          time = start_time - retain_time
          total_size, oldest_list = S3Utilities.list_files_before_time('logs', prefix, time)
          delete_items = []
          oldest_list.each do |item|
            delete_items << { :key => item.key }
          end
          if delete_items.length > 0
            @state = 'DELETING_OBJECTS'
            rubys3_client.delete_objects({ bucket: 'logs', delete: { objects: delete_items } })
            Logger.info("Deleted #{delete_items.length} #{target_name} log files")
          end
        end

        @count += 1
        @state = 'SLEEPING'
        break if @microservice_sleeper.sleep(target.cleanup_poll_time)
      end
    end
  end
end

Cosmos::CleanupMicroservice.run if __FILE__ == $0
