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

require 'fileutils'
require 'json'
require 'cosmos'
require 'cosmos/script'
require 'cosmos/utilities/store'
require 'cosmos/utilities/s3'

class CompletedScript
  BUCKET_NAME = 'logs'
  def self.all(scope)
    Cosmos::S3Utilities.ensure_public_bucket(BUCKET_NAME)
    rubys3_client = Aws::S3::Client.new
    scripts = rubys3_client.list_objects_v2({bucket: BUCKET_NAME, prefix: "#{scope}/tool_logs/sr"}).contents.map do |object|
      log_name = object.key
      year, month, day, hour, minute, second, _ = File.basename(log_name).split('_').map { |num| num.to_i }
      {
        'name' => rubys3_client.head_object(bucket: BUCKET_NAME, key:object.key).metadata['scriptname'],
        'log' => log_name,
        'start' => Time.new(year, month, day, hour, minute, second).to_s
      }
    end
    scripts.sort_by { |script| script['start'] }.reverse
  end
end