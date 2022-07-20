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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'openc3'
require 'tempfile'
require 'openc3/utilities/s3'
OpenC3.require_file 'openc3/utilities/store'
OpenC3.require_file 'openc3/tools/table_manager/table_manager_core'

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
    get_file(scope, name)
  end

  def self.binary(scope, binary_filename, definition_filename = nil, table_name = nil)
    binary = OpenStruct.new
    binary.filename = File.basename(binary_filename)
    binary.contents = get_file(scope, binary_filename)
    if definition_filename && table_name
      root_definition = get_definitions(scope, definition_filename)
      # Convert the typical table naming convention of all caps with underscores
      # to the typical binary convention of camelcase, e.g. MC_CONFIG => McConfig.bin
      filename = table_name.split('_').map { |part| part.capitalize }.join()
      binary.filename = "#{filename}.bin"
      binary.contents = OpenC3::TableManagerCore.binary(binary.contents, root_definition, table_name)
    end
    return binary
  end

  def self.definition(scope, definition_filename, table_name = nil)
    definition = OpenStruct.new
    if table_name
      root_definition = get_definitions(scope, definition_filename)
      definition.filename, definition.contents =
        OpenC3::TableManagerCore.definition(root_definition, table_name)
    else
      definition.filename = File.basename(definition_filename)
      definition.contents = get_file(scope, definition_filename)
    end
    return definition
  end

  def self.report(scope, binary_filename, definition_filename, table_name = nil)
    report = OpenStruct.new
    binary = get_file(scope, binary_filename)
    root_definition = get_definitions(scope, definition_filename)
    if table_name
      # Convert the typical table naming convention of all caps with underscores
      # to the typical binary convention of camelcase, e.g. MC_CONFIG => McConfig.bin
      filename = table_name.split('_').map { |part| part.capitalize }.join()
      report.filename = "#{filename}.csv"
    else
      report.filename = File.basename(binary_filename).sub('.bin', '.csv')
    end
    report.contents = OpenC3::TableManagerCore.report(binary, root_definition, table_name)
    put_file(scope, binary_filename.sub('.bin', '.csv'), report.contents)
    return report
  end

  def self.load(scope, binary_filename, definition_filename)
    binary = get_file(scope, binary_filename)
    root_definition = get_definitions(scope, definition_filename)
    return OpenC3::TableManagerCore.build_json(binary, root_definition)
  end

  def self.save(scope, binary_filename, definition_filename, tables)
    binary = get_file(scope, binary_filename)
    raise "Binary file '#{binary_filename}' not found" unless binary
    root_definition = get_definitions(scope, definition_filename)
    binary = OpenC3::TableManagerCore.save(root_definition, JSON.parse(tables, :allow_nan => true, :create_additions => true))
    put_file(scope, binary_filename, binary)
  end

  def self.save_as(scope, filename, new_filename)
    file = get_file(scope, filename)
    raise "File '#{filename}' not found" unless file
    put_file(scope, new_filename, file)
  end

  def self.generate(scope, definition_filename)
    root_definition = get_definitions(scope, definition_filename)
    binary = OpenC3::TableManagerCore.generate(root_definition)
    binary_filename = "#{File.dirname(definition_filename).sub('/config','/bin')}/#{File.basename(definition_filename)}"
    binary_filename.sub!('_def', '') # Strip off _def from the definition filename
    binary_filename.sub!('.txt', '.bin')
    put_file(scope, binary_filename, binary)
    return binary_filename
  end

  def self.destroy(scope, name)
    # Only delete file from the modified target directory
    Aws::S3::Client.new.delete_object(
      key: "#{scope}/targets_modified/#{name}",
      bucket: DEFAULT_BUCKET_NAME,
    )
    true
  end

  def self.lock(scope, name, user)
    name = name.split('*')[0] # Split '*' that indicates modified
    OpenC3::Store.hset("#{scope}__table-locks", name, user)
  end

  def self.unlock(scope, name)
    name = name.split('*')[0] # Split '*' that indicates modified
    OpenC3::Store.hdel("#{scope}__table-locks", name)
  end

  def self.locked?(scope, name)
    name = name.split('*')[0] # Split '*' that indicates modified
    locked_by = OpenC3::Store.hget("#{scope}__table-locks", name)
    locked_by ||= false
    locked_by
  end

  # Private helper methods

  def self.get_definitions(scope, definition_filename)
    temp_dir = Dir.mktmpdir
    definition = get_file(scope, definition_filename)
    base_definition = File.join(temp_dir, File.basename(definition_filename))
    File.write(base_definition, definition)
    # If the definition includes TABLEFILE we need to load
    # the other definitions locally so we can render them
    base_dir = File.dirname(definition_filename)
    definition.split("\n").each do |line|
      if line.strip =~ /^TABLEFILE (.*)/
        filename = File.join(base_dir, $1.remove_quotes)
        file = get_file(scope, filename)
        raise "Could not find file #{filename}" unless file
        File.write(File.join(temp_dir, File.basename(filename)), file)
      end
    end
    base_definition
  end

  def self.get_file(scope, name)
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
    if name.include?(".bin")
      resp.body.binmode
    end
    resp.body.read
  end

  def self.put_file(scope, name, data)
    rubys3_client = Aws::S3::Client.new
    key = "#{scope}/targets_modified/#{name}"
    rubys3_client.put_object(bucket: DEFAULT_BUCKET_NAME, key: key, body: data)
  end
end
