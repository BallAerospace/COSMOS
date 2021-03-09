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

Cosmos.require_file 'aws-sdk-s3'

Aws.config.update(
  endpoint: ENV['COSMOS_S3_URL'] || ENV['COSMOS_DEVEL'] ? 'http://127.0.0.1:9000' : 'http://cosmos-minio:9000',
  access_key_id: 'minioadmin',
  secret_access_key: 'minioadmin',
  force_path_style: true,
  region: 'us-east-1'
)

module Cosmos
  class S3Utilities
    def self.get_total_size_and_oldest_list(bucket, prefix, max_list_length = 1000)
      rubys3_client = Aws::S3::Client.new
      oldest_list = []
      total_size = 0

      # Return nothing if bucket doesn't exist (it won't at the very beginning)
      begin
        rubys3_client.head_bucket(bucket: bucket)
      rescue Aws::S3::Errors::NotFound
        return total_size, oldest_list
      end

      # Get List of Files from S3
      token = nil
      while true
        resp = rubys3_client.list_objects_v2({
          bucket: bucket,
          max_keys: 10000,
          prefix: prefix,
          continuation_token: token
        })
        resp.contents.each do |item|
          total_size += item.size
        end
        oldest_list.concat(resp.contents)
        oldest_list.sort! {|a,b| File.basename(a.key) <=> File.basename(b.key)}
        oldest_list = oldest_list[0..(max_list_length - 1)]
        break unless resp.is_truncated
        token = resp.next_continuation_token
      end
      return total_size, oldest_list
    end
  end
end
