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


autoload(:Aws, 'cosmos/utilities/s3_autoload.rb')
require 'cosmos/models/target_model'

module Cosmos
  module Api
    WHITELIST ||= []
    WHITELIST.concat([
                       'get_target_list',
                       'get_target',
                       'get_all_target_info',
                       'read_target_file',
                       'write_target_file',
                       'delete_target_file',
                     ])

    # Returns the list of all target names
    #
    # @return [Array<String>] All target names
    def get_target_list(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', scope: scope, token: token)
      TargetModel.names(scope: scope)
    end

    # Gets the full target hash
    #
    # @since 5.0.0
    # @param target_name [String] Target name
    # @return [Hash] Hash of all the target properties
    def get_target(target_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', target_name: target_name, scope: scope, token: token)
      TargetModel.get(name: target_name, scope: scope)
    end

    # Get information about all targets
    #
    # @return [Array<Array<String, Numeric, Numeric>] Array of Arrays \[name, interface, cmd_cnt, tlm_cnt]
    def get_all_target_info(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      info = []
      get_target_list(scope: scope, token: token).each do |target_name|
        cmd_cnt = 0
        packets = TargetModel.packets(target_name, type: :CMD, scope: scope)
        packets.each do |packet|
          cmd_cnt += _get_cnt("#{scope}__COMMAND__{#{target_name}}__#{packet['packet_name']}")
        end
        tlm_cnt = 0
        packets = TargetModel.packets(target_name, type: :TLM, scope: scope)
        packets.each do |packet|
          tlm_cnt += _get_cnt("#{scope}__TELEMETRY__{#{target_name}}__#{packet['packet_name']}")
        end
        interface_name = ''
        InterfaceModel.all(scope: scope).each do |name, interface|
          if interface['target_names'].include? target_name
            interface_name = interface['name']
            break
          end
        end
        info << [target_name, interface_name, cmd_cnt, tlm_cnt]
      end
      info
    end

    # Read a file from a target
    #
    # @param [String] Path to a file in a target directory
    # @param [String] File mode, default is 'r' but you can also pass 'rb' for binary data
    # @return [String|nil]
    def read_target_file(path, mode = 'r', scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      file = nil
      local_path = File.join(Dir.tmpdir, 'cosmos', 'target_files', path)
      FileUtils.mkdir_p(File.dirname(local_path))
      client = Aws::S3::Client.new
      begin
        Cosmos::Logger.info "Reading #{scope}/targets_modified/#{path}, mode #{mode}"
        client.get_object(bucket: "config", key: "#{scope}/targets_modified/#{path}", response_target: local_path)
        return File.read(local_path, mode: mode)
      rescue => error
        # If the item doesn't exist we just continue to check the unmodified targets dir
      end
      begin
        Cosmos::Logger.info "Reading #{scope}/targets/#{path}, mode #{mode}"
        client.get_object(bucket: "config", key: "#{scope}/targets/#{path}", response_target: local_path)
        return File.read(local_path, mode: mode)
      rescue => error
        Cosmos::Logger.error "Failed to retrieve #{path} due to #{error.message}"
        return nil
      end
    end

    # Write a file to a target
    #
    # @param [String] Path to a file in a target directory
    # @param [String] File contents
    # @param [String] File mode, default is 'w' but you can also pass 'wb' for binary data
    def write_target_file(path, contents, mode = 'w', scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      type = case mode
      when 'w'
        'text/plain'
      when 'wb'
        'application/octet-stream'
      else
        Cosmos::Logger.error "Invalid mode #{mode}, must be 'w' or 'wb'."
        return nil
      end
      begin
        Cosmos::Logger.info "Writing #{scope}/targets_modified/#{path}, mode #{mode}"
        Aws::S3::Client.new.put_object(bucket: "config", key: "#{scope}/targets_modified/#{path}", body: contents, content_type: type)
      rescue => error
        Cosmos::Logger.error "Failed writing #{path} due to #{error.message}"
      end
      nil
    end

    # Delete a file on a target
    #
    # @param [String] Path to a file in a target directory
    def delete_target_file(path, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      begin
        # Only delete from the targets_modified
        Cosmos::Logger.info "Deleting #{scope}/targets_modified/#{path}"
        Aws::S3::Client.new.delete_object(bucket: "config", key: "#{scope}/targets_modified/#{path}")
      rescue => error
        Cosmos::Logger.error "Failed deleting #{path} due to #{error.message}"
      end
      nil
    end
  end
end
