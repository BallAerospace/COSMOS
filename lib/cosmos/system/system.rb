# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/config/config_parser'
require 'cosmos/packets/packet_config'
require 'cosmos/packets/commands'
require 'cosmos/packets/telemetry'
require 'cosmos/packets/limits'
require 'cosmos/system/target'
require 'thread'

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
      Store.instance.hget("#{$cosmos_scope}__cosmos_system", 'limits_set').intern
    end

    # Get the singleton instance of System
    #
    # @param target_list [Array of Hashes{target_name, substitute_name, target_filename, target_id}]
    # @param target_config_dir Directory where target config folders are
    # @return [System] The System singleton
    def self.instance(target_list = nil, target_config_dir = nil)
      return @@instance if @@instance
      raise "System.instance parameters are required on first call" unless target_list and target_config_dir
      @@instance_mutex.synchronize do
        @@instance ||= self.new(target_list, target_config_dir)
        return @@instance
      end
    end

    # Create a new System object. Note, this should not be called directly but
    # you should instead use System.instance and treat this class as a
    # singleton.
    #
    # @param target_list [Array of Hashes{target_name, substitute_name, target_filename, target_id}]
    # @param target_config_dir Directory where target config folders are
    def initialize(target_list, target_config_dir)
      raise "Cosmos::System created twice" unless @@instance.nil?
      @targets = {}
      @packet_config = nil
      @commands = nil
      @telemetry = nil
      @limits = nil
      process_targets(target_list, target_config_dir)
      load_packets()
      @@instance = self
    end

    # Create all the Target instances in the system.
    #
    # @param target_list [Array of Hashes{target_name, substitute_name, target_filename, target_id}]
    # @param target_config_dir Directory where target config folders are
    def process_targets(target_list, target_config_dir)
      parser = ConfigParser.new
      target_list.each do |item|
        target_name = item['target_name']
        original_name = item['original_name']
        target_filename = item['target_filename']
        if original_name
          folder_name = File.join(target_config_dir, original_name)
        else
          folder_name = File.join(target_config_dir, target_name)
        end
        raise parser.error("Target folder must exist '#{folder_name}'.") unless Dir.exist?(folder_name)
        target = Target.new(target_name, original_name, target_config_dir, target_filename)
        target.id = item['target_id']
        @targets[target.name] = target
      end
    end

    # Load all of the commands and telemetry into the System
    def load_packets
      # Load configuration
      @packet_config = PacketConfig.new
      @commands = Commands.new(@packet_config)
      @telemetry = Telemetry.new(@packet_config)
      @limits = Limits.new(@packet_config)

      @targets.each do |target_name, target|
        target.cmd_tlm_files.each do |cmd_tlm_file|
          begin
            @packet_config.process_file(cmd_tlm_file, target.name)
          rescue Exception => err
            Logger.error "Problem processing #{cmd_tlm_file}."
            raise err
          end
        end
      end
    end
  end
end
