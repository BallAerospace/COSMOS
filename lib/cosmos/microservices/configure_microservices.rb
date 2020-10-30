# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

$redis_url = ENV['COSMOS_REDIS_URL'] || (ENV['COSMOS_DEVEL'] ? 'redis://127.0.0.1:6379/0' : 'redis://cosmos-redis:6379/0')

require 'cosmos'
require 'cosmos/system/system'
require 'cosmos/models/interface_model'
require 'cosmos/models/router_model'
require 'cosmos/models/microservice_model'
require 'cosmos/models/target_model'
require 'cosmos/models/scope_model'

module Cosmos
  class ConfigureMicroservices
    def initialize(system_config, cts_config, scope:, url: $redis_url, logger: Logger.new(Logger::INFO, true))
      # TODO: What to do with token here, is DEFAULT a special case?
      ScopeModel.new(name: 'DEFAULT').create(scope: 'DEFAULT', token: nil)

      target_list = []
      target_names = []
      system_config.targets.each do |target_name, target|
        original_name = nil
        original_name = target.original_name if target.name != target.original_name
        target_filename = nil
        target_filename = File.basename(target.filename) if target.filename
        target_list << { 'target_name' => target_name, 'original_name' => original_name, 'target_filename' => target_filename, 'target_id' => target.id }
        target_names << target_name
      end
      System.instance(target_list, File.join(system_config.userpath, 'config', 'targets'))

      # Save configuration to redis
      Store.instance.del("#{scope}__cosmos_system")
      Store.instance.hset("#{scope}__cosmos_system", 'limits_set', 'DEFAULT') # Current
      Store.instance.hset("#{scope}__cosmos_system", 'target_names', JSON.generate(target_names))
      System.targets.each do |target_name, target|
        Store.instance.hset("#{scope}__cosmos_targets", target_name, JSON.generate(target.as_json))
      end
      Store.instance.hset("#{scope}__cosmos_system", 'limits_sets', JSON.generate(System.packet_config.limits_sets))
      Store.instance.hset("#{scope}__cosmos_system", 'limits_groups', JSON.generate(System.packet_config.limits_groups))

      System.telemetry.all.each do |target_name, packets|
        Store.instance.del("#{scope}__cosmostlm__#{target_name}")
        packets.each do |packet_name, packet|
          logger.info "Configuring tlm packet: #{target_name} #{packet_name}"
          Store.instance.hset("#{scope}__cosmostlm__#{target_name}", packet_name, JSON.generate(packet.as_json))
        end
      end
      System.commands.all.each do |target_name, packets|
        Store.instance.del("#{scope}__cosmoscmd__#{target_name}")
        packets.each do |packet_name, packet|
          logger.info "Configuring cmd packet: #{target_name} #{packet_name}"
          Store.instance.hset("#{scope}__cosmoscmd__#{target_name}", packet_name, JSON.generate(packet.as_json))
        end
      end

      # Configure microservices
      # TODO - Just delete for current scope
      Store.instance.del("cosmos_microservices")

      cts_config.interfaces.each do |interface_name, interface|
        # Configure InterfaceMicroservice
        target_list = []
        interface.target_names.each do |target_name|
          target = system_config.targets[target_name]
          original_name = nil
          original_name = target.original_name if target.name != target.original_name
          target_filename = nil
          target_filename = File.basename(target.filename) if target.filename
          target_list << { 'target_name' => target_name, 'original_name' => original_name, 'target_filename' => target_filename, 'target_id' => target.id }
        end
        config = { 'filename' => "interface_microservice.rb", 'interface_params' => interface.config_params, 'target_list' => target_list, 'scope' => scope }
        name = "#{scope}__INTERFACE__#{interface_name}"
        Store.instance.hset("cosmos_microservices", name, JSON.generate(config))
        logger.info "Configured microservice #{name}"

        # Configure DecomMicroservice
        command_topic_list = []
        packet_topic_list = []
        interface.target_names.each do |target_name|
          begin
            System.commands.packets(target_name).each do |packet_name, packet|
              command_topic_list << "#{scope}__COMMAND__#{target_name}__#{packet_name}"
            end
            System.telemetry.packets(target_name).each do |packet_name, packet|
              packet_topic_list << "#{scope}__TELEMETRY__#{target_name}__#{packet_name}"
            end
          rescue
            # No telemetry packets for this target
          end
        end
        Store.instance.initialize_streams(command_topic_list)
        Store.instance.initialize_streams(packet_topic_list)
        next unless packet_topic_list.length > 0

        config = { 'filename' => "decom_microservice.rb", 'target_list' => target_list, 'topics' => packet_topic_list, 'scope' => scope }
        name = "#{scope}__DECOM__#{interface_name}"
        Store.instance.hset("cosmos_microservices", name, JSON.generate(config))
        logger.info "Configured microservice #{name}"

        # Configure CvtMicroservice
        decom_topic_list = []
        interface.target_names.each do |target_name|
          begin
            System.telemetry.packets(target_name).each do |packet_name, packet|
              decom_topic_list << "#{scope}__DECOM__#{target_name}__#{packet_name}"
            end
          rescue
            # No telemetry packets for this target
          end
        end
        config = { 'filename' => "cvt_microservice.rb", 'topics' => decom_topic_list, 'scope' => scope }
        name = "#{scope}__CVT__#{interface_name}"
        Store.instance.hset("cosmos_microservices", name, JSON.generate(config))
        logger.info "Configured microservice #{name}"

        # Configure PacketLogMicroservice
        config = { 'filename' => "packet_log_microservice.rb", 'target_list' => target_list, 'topics' => packet_topic_list, 'scope' => scope }
        name = "#{scope}__PACKETLOG__#{interface_name}"
        Store.instance.hset("cosmos_microservices", name, JSON.generate(config))
        logger.info "Configured microservice #{name}"

        # Configure DecomLogMicroservice
        config = { 'filename' => "decom_log_microservice.rb", 'target_list' => target_list, 'topics' => decom_topic_list, 'scope' => scope }
        name = "#{scope}__DECOMLOG__#{interface_name}"
        Store.instance.hset("cosmos_microservices", name, JSON.generate(config))
        logger.info "Configured microservice #{name}"


      end
    end
  end
end
