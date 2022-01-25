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

require 'open-uri'
require 'nokogiri'
require 'httpclient'
require 'cosmos/utilities/s3'

module Cosmos
  # This class acts like a Model but doesn't inherit from Model because it doesn't
  # actual interact with the Store (Redis). Instead we implement names, get, put
  # and destroy to allow interaction with files from S3.
  class TableModel
    def self.names
      gems = []
      Aws::S3::Client.new.list_objects(bucket: 'config').contents.each do |object|
        gems << object.key
      end
      gems
    end

    def self.get(dir, name)
      rubys3_client = Aws::S3::Client.new()
      path = File.join(dir, name)
      rubys3_client.get_object(bucket: 'config', key: name, response_target: path)
      return path
    end

    def self.put(table_file_path)
      if File.file?(table_file_path)
        table_filename = File.basename(table_file_path)
        File.open(table_file_path, 'rb') do |file|
          Aws::S3::Client.new().put_object(bucket: 'config', key: table_filename, body: file)
        end
      else
        message = "Table file #{table_file_path} does not exist!"
        Logger.error message
        raise message
      end
    end

    def self.destroy(name)
      rubys3_client = Aws::S3::Client.new()
      rubys3_client.delete_object(bucket: 'config', key: name)
    end
  end
end
