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

autoload(:Aws, 'openc3/utilities/s3_autoload.rb')
require 'openc3/models/reducer_model'

module OpenC3
  class S3Utilities
    def self.list_files_before_time(bucket, prefix, time)
      rubys3_client = Aws::S3::Client.new
      oldest_list = []
      total_size = 0

      # Return nothing if bucket doesn't exist (it won't at the very beginning)
      begin
        rubys3_client.head_bucket(bucket: bucket)
      rescue Aws::S3::Errors::NotFound
        return total_size, oldest_list
      end

      # Get List of Packet Names - Assumes prefix gets us to a folder of packet names
      token = nil
      folder_list = []
      while true
        resp = rubys3_client.list_objects_v2({
          bucket: bucket,
          max_keys: 1000,
          prefix: prefix,
          delimiter: '/',
          continuation_token: token
        })

        resp.common_prefixes.each do |item|
          folder_list << item.prefix
        end
        break unless resp.is_truncated
        token = resp.next_continuation_token
      end

      # Go through each folder and keep files that end before time
      folder_list.each do |folder|
        token = nil
        next_folder = false
        while true
          resp = rubys3_client.list_objects_v2({
                                                bucket: bucket,
                                                max_keys: 1000,
                                                prefix: folder,
                                                continuation_token: token
                                              })
          resp.contents.each do |item|
            t = item.key.split('__')[1]
            file_end_time = Time.utc(t[0..3], t[4..5], t[6..7], t[8..9], t[10..11], t[12..13])
            if file_end_time < time
              oldest_list << item
              total_size += item.size
            else
              next_folder = true
              break
            end
          end
          break if !resp.is_truncated or next_folder

          token = resp.next_continuation_token
        end
      end
      return total_size, oldest_list
    end

    def self.get_total_size_and_oldest_list(bucket, prefix, max_list_length = 10000)
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
                                               max_keys: 1000,
                                               prefix: prefix,
                                               continuation_token: token
                                             })
        resp.contents.each do |item|
          total_size += item.size
        end
        oldest_list.concat(resp.contents)
        oldest_list.sort! { |a, b| File.basename(a.key) <=> File.basename(b.key) }
        oldest_list = oldest_list[0..(max_list_length - 1)]
        break unless resp.is_truncated

        token = resp.next_continuation_token
      end
      return total_size, oldest_list
    end

    def self.move_log_file_to_s3(filename, s3_key, metadata: {})
      Thread.new do
        rubys3_client = Aws::S3::Client.new

        # Ensure logs bucket exists
        begin
          rubys3_client.head_bucket(bucket: 'logs')
        rescue Aws::S3::Errors::NotFound
          rubys3_client.create_bucket(bucket: 'logs')
        end

        # Write to S3 Bucket
        File.open(filename, 'rb') do |read_file|
          rubys3_client.put_object(bucket: 'logs', key: s3_key, body: read_file, metadata: metadata)
        end
        Logger.debug "logs/#{s3_key} written to S3"
        ReducerModel.add_file(s3_key) # Record the new file for data reduction

        File.delete(filename)
      rescue => err
        Logger.error("Error saving log file to bucket: #{filename}\n#{err.formatted}")
      end
    end

    def self.ensure_public_bucket(bucket_name)
      rubys3_client = Aws::S3::Client.new
      begin
        rubys3_client.head_bucket(bucket: bucket_name)
      rescue Aws::S3::Errors::NotFound
        rubys3_client.create_bucket(bucket: bucket_name)

        policy = <<~EOL
          {
            "Version": "2012-10-17",
            "Statement": [
              {
                "Action": [
                  "s3:GetBucketLocation",
                  "s3:ListBucket"
                ],
                "Effect": "Allow",
                "Principal": {
                  "AWS": [
                    "*"
                  ]
                },
                "Resource": [
                  "arn:aws:s3:::#{bucket_name}"
                ],
                "Sid": ""
              },
              {
                "Action": [
                  "s3:GetObject"
                ],
                "Effect": "Allow",
                "Principal": {
                  "AWS": [
                    "*"
                  ]
                },
                "Resource": [
                  "arn:aws:s3:::#{bucket_name}/*"
                ],
                "Sid": ""
              }
            ]
          }
        EOL

        rubys3_client.put_bucket_policy({ bucket: bucket_name, policy: policy })
      end
    end

    def self.get_cache_control(filename)
      # Allow caching for files that have a filename versioning strategy
      has_version_number = /(-|_|\.)\d+(-|_|\.)\d+(-|_|\.)\d+\./.match(@filename)
      has_content_hash = /\.[a-f0-9]{20}\./.match(@filename)
      return nil if has_version_number or has_content_hash
      return 'no-cache'
    end
  end
end
