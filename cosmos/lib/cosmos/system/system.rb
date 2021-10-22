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

require 'cosmos/config/config_parser'
require 'cosmos/packets/packet_config'
require 'cosmos/packets/commands'
# TODO: System requires telemetry and Telemetry require system ... circular reference
require 'cosmos/packets/telemetry'
require 'cosmos/packets/limits'
require 'cosmos/system/target'
require 'cosmos/utilities/s3'
require 'cosmos/utilities/zip'
require 'thread'
require 'fileutils'

module Cosmos
  class System
    # @return [Hash<String,Target>] Hash of all the known targets
    instance_attr_reader :targets

    # @return [PacketConfig] Access to the packet configuration
    instance_attr_reader :packet_config

    # @return [Commands] Access to the command definition
    instance_attr_reader :commands

    # @return [Telemetry] Access to the telemetry definition
    instance_attr_reader :telemetry

    # @return [Limits] Access to the limits definition
    instance_attr_reader :limits

    # Variable that holds the singleton instance
    @@instance = nil

    # Mutex used to ensure that only one instance of System is created
    @@instance_mutex = Mutex.new

    # @return [Symbol] The current limits_set of the system returned from Redis
    def self.limits_set
      Store.hget("#{$cosmos_scope}__cosmos_system", 'limits_set').intern
    end

    def self.setup_targets(target_names, base_dir, scope:)
      FileUtils.mkdir_p("#{base_dir}/targets")
      rubys3_client = Aws::S3::Client.new
      target_names.each do |target_name|
        # Retrieve bucket/targets/target_name/target_id.zip
        response_target = "#{base_dir}/targets/#{target_name}_current.zip"
        FileUtils.mkdir_p(File.dirname(response_target))
        s3_key = "#{scope}/target_archives/#{target_name}/#{target_name}_current.zip"
        Logger.info("Retrieving #{s3_key} from targets bucket")
        rubys3_client.get_object(bucket: "config", key: s3_key, response_target: response_target)
        Zip::File.open(response_target) do |zip_file|
          zip_file.each do |entry|
            path = File.join("#{base_dir}/targets", entry.name)
            FileUtils.mkdir_p(File.dirname(path))
            zip_file.extract(entry, path) unless File.exist?(path)
          end
        end
      end

      # Build System from targets
      System.instance(target_names, "#{base_dir}/targets")
    end

    # Get the singleton instance of System
    #
    # @param target_names [Array of target_names]
    # @param target_config_dir Directory where target config folders are
    # @return [System] The System singleton
    def self.instance(target_names = nil, target_config_dir = nil)
      return @@instance if @@instance
      raise "System.instance parameters are required on first call" unless target_names and target_config_dir

      @@instance_mutex.synchronize do
        @@instance ||= self.new(target_names, target_config_dir)
        return @@instance
      end
    end

    # Create a new System object.
    #
    # @param target_names [Array of target names]
    # @param target_config_dir Directory where target config folders are
    def initialize(target_names, target_config_dir)
      @targets = {}
      @packet_config = PacketConfig.new
      @commands = Commands.new(@packet_config)
      @telemetry = Telemetry.new(@packet_config)
      @limits = Limits.new(@packet_config)
      target_names.each { |target_name| add_target(target_name, target_config_dir) }
    end

    def add_target(target_name, target_config_dir)
      parser = ConfigParser.new
      folder_name = File.join(target_config_dir, target_name)
      raise parser.error("Target folder must exist '#{folder_name}'.") unless Dir.exist?(folder_name)

      target = Target.new(target_name, target_config_dir)
      @targets[target.name] = target
      target.cmd_tlm_files.each do |cmd_tlm_file|
        @packet_config.process_file(cmd_tlm_file, target.name)
      rescue Exception => err
        Logger.error "Problem processing #{cmd_tlm_file}: #{err}."
        raise err
      end
    end
  end
end
