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

require 'cosmos'
require 'tempfile'
require 'cosmos/utilities/s3'
Cosmos.require_file 'cosmos/utilities/store'
Cosmos.require_file 'cosmos/tools/table_manager/table_manager_core'

class Table
  DEFAULT_BUCKET_NAME = 'config'

  def self.all(scope)
    rubys3_client = Aws::S3::Client.new
    resp = rubys3_client.list_objects_v2(bucket: DEFAULT_BUCKET_NAME)
    result = []
    modified = []
    contents = resp.to_h[:contents]
    if contents
      contents.each do |object|
        next unless object[:key].include?("#{scope}/targets")

        if object[:key].include?('tables')
          if object[:key].include?("#{scope}/targets_modified")
            modified << object[:key].split('/')[2..-1].join('/')
            next
          end
          result << object[:key].split('/')[2..-1].join('/')
        end
      end
    end

    # Determine if there are any modified files and mark them with '*'
    result.map! do |file|
      if modified.include?(file)
        modified.delete(file)
        "#{file}*"
      else
        file
      end
    end

    # Concat any remaining modified files (new files not in original target)
    result.concat(modified)
    result.sort
  end

  def self.body(scope, name)
    name = name.split('*')[0] # Split '*' that indicates modified
    rubys3_client = Aws::S3::Client.new
    begin
      # First try opening a potentially modified version by looking for the modified target
      resp =
        rubys3_client.get_object(
          bucket: DEFAULT_BUCKET_NAME,
          key: "#{scope}/targets_modified/#{name}",
        )
    rescue StandardError
      # Now try the original
      resp =
        rubys3_client.get_object(
          bucket: DEFAULT_BUCKET_NAME,
          key: "#{scope}/targets/#{name}",
        )
    end
    resp.body.read
  end

  def self.create(scope, name, table = nil)
    return false unless table

    temp_dir = Dir.mktmpdir
    result = false
    begin
      table_file_path = temp_dir + '/' + table.original_filename
      FileUtils.cp(table.tempfile.path, table_file_path)

      if File.file?(table_file_path)
        File.open(table_file_path, 'rb') do |file|
          Aws::S3::Client.new().put_object(bucket: DEFAULT_BUCKET_NAME, key: "#{scope}/targets_modified/#{name}", body: file)
        end
      else
        message = "Table file #{table_file_path} does not exist!"
        Logger.error message
        raise message
      end
    ensure
      FileUtils.remove_entry(temp_dir) if temp_dir and File.exist?(temp_dir)
    end
    true
  end

  def self.generate(scope, name, definition)
    return false unless definition

    temp_dir = Dir.mktmpdir
    begin
      definition_path = temp_dir + '/def.txt'
      File.open(definition_path, 'w') do |file|
        file.write(definition)
      end
      binary = Cosmos::TableManagerCore.new.file_new(definition_path, temp_dir)
      File.open(binary, 'rb') do |file|
        Aws::S3::Client.new().put_object(bucket: DEFAULT_BUCKET_NAME, key: "#{scope}/targets_modified/#{name.sub('_def','').sub(".txt",".bin")}", body: file)
      end
    ensure
      FileUtils.remove_entry(temp_dir) if temp_dir and File.exist?(temp_dir)
    end
    true
  end

  def self.destroy(scope, name)
    rubys3_client = Aws::S3::Client.new

    # Only delete file from the modified target directory
    rubys3_client.delete_object(
      key: "#{scope}/targets_modified/#{name}",
      bucket: DEFAULT_BUCKET_NAME,
    )
    true
  end

  def self.lock(scope, name, user)
    name = name.split('*')[0] # Split '*' that indicates modified
    Cosmos::Store.hset("#{scope}__table-locks", name, user)
  end

  def self.unlock(scope, name)
    name = name.split('*')[0] # Split '*' that indicates modified
    Cosmos::Store.hdel("#{scope}__table-locks", name)
  end

  def self.locked?(scope, name)
    name = name.split('*')[0] # Split '*' that indicates modified
    locked_by = Cosmos::Store.hget("#{scope}__table-locks", name)
    locked_by ||= false
    locked_by
  end
end
