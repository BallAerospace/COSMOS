# encoding: ascii-8bit

# Copyright 2018 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require File.expand_path('../../config/environment', __FILE__)
require 'dart_common'
require 'dart_logging'

class DartWorker
  include DartCommon

  def initialize(mod_index = 0, modulus = 1)
    sync_targets_and_packets()
    build_lookups()
    @mod_index = mod_index
    @modulus = modulus
  end

  def decom_packet(ple, packet, packet_id, packet_config_id)
    values = []

    packet.sorted_items.each do |item|
      # We don't handle DERIVED items without explicit types and sizes
      if item.data_type == :DERIVED
        next unless item.read_conversion and item.read_conversion.converted_type and item.read_conversion.converted_bit_size
      end

      if separate_raw_con?(item)
        values << packet.read_item(item, :RAW)
        values << packet.read_item(item, :CONVERTED)
      else
        values << packet.read_item(item, :RAW)
      end
    end

    table_index = 0
    rows = []
    values.each_slice(MAX_COLUMNS_PER_TABLE) do |table_values|
      model = get_decom_table_model(packet_config_id, table_index)
      row = model.new
      row.time = ple.time
      row.ple_id = ple.id
      row.meta_id = ple.meta_id
      row.reduced_state = -1
      table_values.each_with_index do |value, index|
        item_index = (table_index * MAX_COLUMNS_PER_TABLE) + index
        row.write_attribute("i#{item_index}", value)
      end
      row.save
      rows << row
      table_index += 1
    end

    # Mark ready to reduce
    rows.each do |row|
      row.reduced_state = 0
      row.save
    end
  end

  def start
    begin
      while true
        # Check for new data to decom
        time_start = Time.now
        PacketLogEntry.where("decom_state = #{PacketLogEntry::NOT_STARTED} and ready = true").where("id % #{@modulus} = #{@mod_index}").order("id ASC").in_batches do |group|
          group.each do |ple|
            begin
              # TODO - Optimize and cache meta and system config and packet config lookup

              # Find meta ple for this ple
              begin
                if ple.meta_id != ple.id
                  meta_ple = PacketLogEntry.find(ple.meta_id)
                else
                  meta_ple = ple
                end
              rescue => err
                ple.decom_state = PacketLogEntry::NO_META_PLE
                ple.save
                Cosmos::Logger.error("PLE:#{ple.id}:#{ple.decom_state_string}")
                next
              end

              # Read the SYSTEM META packet
              meta_packet = read_packet_from_ple(meta_ple)
              unless meta_packet
                ple.decom_state = PacketLogEntry::NO_META_PACKET
                ple.save
                Cosmos::Logger.error("PLE:#{ple.id}:#{ple.decom_state_string}")
                next
              end

              # Get the System Config
              system_config_name = meta_packet.read("CONFIG")
              system_config = SystemConfig.where("name = ?", system_config_name).first
              begin
                system_config = SystemConfig.create(:name => system_config_name) unless system_config
              rescue
                # Another thread probably already created it - Try to get it one more time
                system_config = SystemConfig.where("name = ?", system_config_name).first
              end
              unless system_config
                ple.decom_state = PacketLogEntry::NO_SYSTEM_CONFIG
                ple.save
                Cosmos::Logger.error("PLE:#{ple.id}:#{ple.decom_state_string}")
                next
              end

              # Switch to this system_config
              begin
                switch_and_get_system_config(system_config_name)
              rescue
                Cosmos::Logger.error("Could not load system_config: #{system_config_name}")
                ple.decom_state = PacketLogEntry::NO_CONFIG
                ple.save
                Cosmos::Logger.error("PLE:#{ple.id}:#{ple.decom_state_string}")
                next
              end

              # Read the actual packet
              packet = read_packet_from_ple(ple)
              unless packet
                ple.decom_state = PacketLogEntry::NO_PACKET
                ple.save
                Cosmos::Logger.error("PLE:#{ple.id}:#{ple.decom_state_string}")
                next
              end

              packet_id = ple.packet_id

              # Have the packet and the system configuration - Need to lookup the data on where to decom to
              packet_config = PacketConfig.where("packet_id = ? and name = ?", packet_id, packet.config_name).first
              begin
                unless packet_config
                  Cosmos::Logger.info("Creating PacketConfig: #{packet.config_name}...")
                  packet_config = PacketConfig.create(:packet_id => packet_id, :name => packet.config_name, :first_system_config_id => system_config.id)
                  setup_packet_config(packet, packet_id, packet_config)
                  Cosmos::Logger.info("Successfully Created PacketConfig: #{packet.config_name}")
                end
              rescue => err
                Cosmos::Logger.error(err.formatted)
                # Another thread probably already created it - Try to get it one more time
                packet_config = PacketConfig.where("packet_id = ? and name = ?", packet_id, packet.config_name).first
              end

              unless packet_config
                ple.decom_state = PacketLogEntry::NO_PACKET_CONFIG
                ple.save
                Cosmos::Logger.error("PLE:#{ple.id}:#{ple.decom_state_string}")
                next
              end

              first = true
              while !packet_config.ready
                if first
                  ready_wait_start = Time.now
                  Cosmos::Logger.info("Waiting for PacketConfig:#{packet_config.id}...")
                  first = false
                end
                sleep(1)
                packet_config.reload

                if (Time.now - ready_wait_start) > 60
                  Cosmos::Logger.fatal("Timeout waiting for ready on PacketConfig:#{packet_config.id}")
                  exit(0)
                end
              end

              # Ready to decom!
              ple.decom_state = PacketLogEntry::IN_PROGRESS
              ple.save
              decom_packet(ple, packet, packet_id, packet_config.id)
              ple.decom_state = PacketLogEntry::COMPLETE
              ple.save

              if ple.decom_state == PacketLogEntry::COMPLETE
                Cosmos::Logger.debug("PLE:#{ple.id}:#{ple.decom_state_string}")
              else
                Cosmos::Logger.warn("PLE:#{ple.id}:#{ple.decom_state_string}")
              end
            rescue => err
              Cosmos::Logger.error("PLE:#{ple.id}:ERROR")
              Cosmos::Logger.error(err.formatted)
            end
          end # Each ple
        end # batches

        # Throttle to no faster than 1 Hz
        delta = Time.now - time_start
        if delta < 1 and delta > 0
          sleep(1 - delta)
        end
      end
    rescue Interrupt
      Cosmos::Logger.info("Dart Worker Closing From Signal...")
    end

    Cosmos::Logger.info("DataWorker completed")
  end

end # class DartWorker

Cosmos.catch_fatal_exception do
  DartCommon.handle_argv

  mod_index = ARGV[0]
  mod_index ||= 0
  mod_index = mod_index.to_i
  modulus = ARGV[1]
  modulus ||= 1
  modulus = modulus.to_i

  Cosmos::Logger.level = Cosmos::Logger::INFO
  dart_logging = DartLogging.new("dart_worker_#{mod_index}")
  Cosmos::Logger.info("Dart Worker Starting...")
  raise "Worker count #{modulus} invalid" if modulus < 1
  raise "Worker id #{mod_index} too high for worker count of #{modulus}" if mod_index >= modulus
  dw = DartWorker.new(mod_index, modulus)
  dw.start
  shutdown_cmd_tlm()
  dart_logging.stop
end
