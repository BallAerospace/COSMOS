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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'fileutils'
require 'json'
require 'openc3'
require 'openc3/script'
require 'openc3/utilities/store'
require 'openc3/utilities/s3'

class CompletedScript
  BUCKET_NAME = 'logs'
  def self.all(scope)
    OpenC3::S3Utilities.ensure_public_bucket(BUCKET_NAME)
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
