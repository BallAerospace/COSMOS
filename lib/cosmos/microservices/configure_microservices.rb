# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos
  class ConfigureMicroservices
    def initialize(system_config, cts_config, url: "redis://localhost:6379/0", logger: Logger.new(Logger::INFO, true))
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
      Store.instance.del("cosmos_system")
      Store.instance.hset('cosmos_system', 'limits_set', 'DEFAULT') # Current
      Store.instance.hset('cosmos_system', 'limits_sets', JSON.generate(['DEFAULT'])) # Array of possible sets
      Store.instance.hset('cosmos_system', 'target_names', JSON.generate(target_names))
      System.targets.each do |target_name, target|
        Store.instance.hset('cosmos_targets', target_name, JSON.generate(target.as_json))
      end

      System.telemetry.all.each do |target_name, packets|
        Store.instance.del("cosmostlm__#{target_name}")
        packets.each do |packet_name, packet|
          logger.info "Configuring tlm packet: #{target_name} #{packet_name}"
          Store.instance.hset("cosmostlm__#{target_name}", packet_name, JSON.generate(packet.as_json))
        end
      end
      System.commands.all.each do |target_name, packets|
        Store.instance.del("cosmoscmd__#{target_name}")
        packets.each do |packet_name, packet|
          logger.info "Configuring cmd packet: #{target_name} #{packet_name}"
          Store.instance.hset("cosmoscmd__#{target_name}", packet_name, JSON.generate(packet.as_json))
        end
      end

      # Configure microservices
      # TODO: Need to only clear out old microservices that are unneeded for the current PROGRAM
      # For now just clear them all
      Store.instance.del('cosmos_microservices')

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
        config = { 'filename' => "interface_microservice.rb", 'interface_params' => interface.config_params, 'target_list' => target_list }
        Store.instance.hset('cosmos_microservices', "INTERFACE__#{interface_name}", JSON.generate(config))
        logger.info "Configured microservice INTERFACE__#{interface_name}"

        # Configure DecomMicroservice
        packet_topic_list = []
        interface.target_names.each do |target_name|
          begin
            System.telemetry.packets(target_name).each do |packet_name, packet|
              packet_topic_list << "TELEMETRY__#{target_name}__#{packet_name}"
            end
          rescue
            # No telemetry packets for this target
          end
        end
        next unless packet_topic_list.length > 0

        config = { 'filename' => "decom_microservice.rb", 'target_list' => target_list, 'topics' => packet_topic_list }
        Store.instance.hset('cosmos_microservices', "DECOM__#{interface_name}", JSON.generate(config))
        logger.info "Configured microservice DECOM__#{interface_name}"

        # Configure CvtMicroservice
        decom_topic_list = []
        interface.target_names.each do |target_name|
          begin
            System.telemetry.packets(target_name).each do |packet_name, packet|
              decom_topic_list << "DECOM__#{target_name}__#{packet_name}"
            end
          rescue
            # No telemetry packets for this target
          end
        end
        config = { 'filename' => "cvt_microservice.rb", 'topics' => decom_topic_list }
        Store.instance.hset('cosmos_microservices', "CVT__#{interface_name}", JSON.generate(config))
        logger.info "Configured microservice CVT__#{interface_name}"

        # Configure PacketLogMicroservice
        config = { 'filename' => "packet_log_microservice.rb", 'topics' => packet_topic_list }
        Store.instance.hset('cosmos_microservices', "PACKETLOG__#{interface_name}", JSON.generate(config))
        logger.info "Configured microservice PACKETLOG__#{interface_name}"

        # Configure DecomLogMicroservice
        config = { 'filename' => "decom_log_microservice.rb", 'topics' => decom_topic_list }
        Store.instance.hset('cosmos_microservices', "DECOMLOG__#{interface_name}", JSON.generate(config))
        logger.info "Configured microservice DECOMLOG__#{interface_name}"
      end
    end
  end
end
