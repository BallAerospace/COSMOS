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

  def self.save(scope, binary_filename, definition_filename, tables = nil)
    raise "Tables parameter empty!" unless tables
    binary = Table.body(scope, binary_filename)
    raise "Binary file '#{binary_filename}' not found" unless binary
    definition = Table.body(scope, definition_filename)
    raise "Definition file '#{definition_filename}' not found" unless definition
    temp_dir = Dir.mktmpdir
    definition_path = "#{temp_dir}/#{File.basename(definition_filename)}"
    begin
      binary_path = temp_dir + '/data.bin'
      File.open(binary_path, 'w') do |file|
        file.write(binary)
      end
      Table.get_definitions(scope, definition_filename, definition).each do |name, contents|
        path = "#{temp_dir}/#{File.basename(name)}"
        File.open(path, 'w') do |file|
          file.write(contents)
        end
      end
      binary = Cosmos::TableManagerCore.new.save_tables(binary_path, definition_path, JSON.parse(tables))
      binary_s3_path = "#{scope}/targets_modified/#{binary_filename}"
      File.open(binary, 'rb') do |file|
        Aws::S3::Client.new().put_object(bucket: DEFAULT_BUCKET_NAME, key: binary_s3_path, body: file)
      end
    ensure
      FileUtils.remove_entry(temp_dir) if temp_dir and File.exist?(temp_dir)
    end
    true
  end

  def self.save_as(scope, filename, new_filename)
    file = Table.body(scope, filename)
    raise "File '#{filename}' not found" unless file
    s3_path = "#{scope}/targets_modified/#{new_filename}"
    Aws::S3::Client.new().put_object(bucket: DEFAULT_BUCKET_NAME, key: s3_path, body: file)
    true
  end

  def self.generate(scope, definition_filename, definition)
    return false unless definition

    tgt_s3_filename = nil
    temp_dir = Dir.mktmpdir
    definition_path = "#{temp_dir}/#{File.basename(definition_filename)}"
    begin
      Table.get_definitions(scope, definition_filename, definition).each do |name, contents|
        path = "#{temp_dir}/#{File.basename(name)}"
        File.open(path, 'w') do |file|
          file.write(contents)
        end
      end
      binary = Cosmos::TableManagerCore.new.file_new(definition_path, temp_dir)
      tgt_s3_filename = "#{File.dirname(definition_filename).sub('/config','/bin')}/#{File.basename(binary)}"
      File.open(binary, 'rb') do |file|
        # Any modifications to the plug-in (including File->New) goes in targets_modified
        Aws::S3::Client.new().put_object(bucket: DEFAULT_BUCKET_NAME, key: "#{scope}/targets_modified/#{tgt_s3_filename}", body: file)
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
    definition_path = "#{temp_dir}/#{File.basename(definition_filename)}"
    begin
      binary_path = temp_dir + '/data.bin'
      File.open(binary_path, 'wb') do |file|
        file.write(binary)
      end
      Table.get_definitions(scope, definition_filename, definition).each do |name, contents|
        path = "#{temp_dir}/#{File.basename(name)}"
        File.open(path, 'w') do |file|
          file.write(contents)
        end
      end
      json = Cosmos::TableManagerCore.new.generate_json(binary_path, definition_path)
    ensure
      FileUtils.remove_entry(temp_dir) if temp_dir and File.exist?(temp_dir)
    end
    json
  end

  def self.report(scope, binary_filename, definition_filename)
    binary = Table.body(scope, binary_filename)
    return nil unless binary
    definition = Table.body(scope, definition_filename)
    return nil unless definition

    report = "File Binary, #{binary_filename}\n"
    report += "File Definition, #{definition_filename}\n\n"
    temp_dir = Dir.mktmpdir
    definition_path = "#{temp_dir}/#{File.basename(definition_filename)}"
    begin
      binary_path = temp_dir + '/data.bin'
      File.open(binary_path, 'wb') do |file|
        file.write(binary)
      end
      Table.get_definitions(scope, definition_filename, definition).each do |name, contents|
        path = "#{temp_dir}/#{File.basename(name)}"
        File.open(path, 'w') do |file|
          file.write(contents)
        end
      end
      report += Cosmos::TableManagerCore.new.file_report(binary_path, definition_path)
    ensure
      FileUtils.remove_entry(temp_dir) if temp_dir and File.exist?(temp_dir)
    end
    report
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

  def self.get_definitions(scope, name, definition)
    files = { name => definition }
    # If the definition includes TABLEFILE we need to load
    # the other definitions locally so we can render them
    base_dir = File.dirname(name)
    definition.split("\n").each do |line|
      if line.strip =~ /^TABLEFILE (.*)/
        filename = File.join(base_dir, $1.remove_quotes)
        files[filename] = Table.body(scope, filename)
        raise "Could not find file #{filename}" unless files[filename]
      end
    end
    files
  end
end
