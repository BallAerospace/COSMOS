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
    rescue Aws::S3::Errors::NoSuchKey
      begin
        # Now try the original
        resp =
          rubys3_client.get_object(
            bucket: DEFAULT_BUCKET_NAME,
            key: "#{scope}/targets/#{name}",
          )
      rescue Aws::S3::Errors::NoSuchKey
        return nil
      end
    end
    resp.body.read
  end

  def self.save(scope, binary_filename, definition_filename, table = nil)
    return false unless table

    binary = Table.body(scope, binary_filename)
    return nil unless binary
    definition = Table.body(scope, definition_filename)
    return nil unless definition
    temp_dir = Dir.mktmpdir
    begin
      binary_path = temp_dir + '/data.bin'
      File.open(binary_path, 'w') do |file|
        file.write(binary)
      end
      definition_path = temp_dir + '/def.txt'
      File.open(definition_path, 'w') do |file|
        file.write(definition)
      end
      binary = Cosmos::TableManagerCore.new.save_json(binary_path, definition_path, JSON.parse(table))
      binary_s3_path = "#{scope}/targets_modified/#{binary_filename}"
      File.open(binary, 'rb') do |file|
        Aws::S3::Client.new().put_object(bucket: DEFAULT_BUCKET_NAME, key: binary_s3_path, body: file)
      end
    ensure
      FileUtils.remove_entry(temp_dir) if temp_dir and File.exist?(temp_dir)
    end
    true
  end

  def self.generate(scope, name, definition)
    return false unless definition

    tgt_s3_filename = nil
    temp_dir = Dir.mktmpdir
    begin
      definition_path = "#{temp_dir}/#{File.basename(name)}"
      File.open(definition_path, 'w') do |file|
        file.write(definition)
      end
      binary = Cosmos::TableManagerCore.new.file_new(definition_path, temp_dir)
      tgt_s3_filename = "#{File.dirname(name).sub('/config','/bin')}/#{File.basename(binary)}"
      File.open(binary, 'rb') do |file|
        # Generating a file means doing File->New so it goes in the root targets dir (non-modified)
        Aws::S3::Client.new().put_object(bucket: DEFAULT_BUCKET_NAME, key: "#{scope}/targets/#{tgt_s3_filename}", body: file)
      end
    ensure
      FileUtils.remove_entry(temp_dir) if temp_dir and File.exist?(temp_dir)
    end
    tgt_s3_filename
  end

  def self.load(scope, binary_filename, definition_filename)
    binary = Table.body(scope, binary_filename)
    return nil unless binary
    definition = Table.body(scope, definition_filename)
    return nil unless definition
    json = ''
    temp_dir = Dir.mktmpdir
    begin
      binary_path = temp_dir + '/data.bin'
      File.open(binary_path, 'wb') do |file|
        file.write(binary)
      end
      definition_path = temp_dir + '/def.txt'
      File.open(definition_path, 'w') do |file|
        file.write(definition)
      end
      json = Cosmos::TableManagerCore.new.generate_json(binary_path, definition_path)
    ensure
      FileUtils.remove_entry(temp_dir) if temp_dir and File.exist?(temp_dir)
    end
    json
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
