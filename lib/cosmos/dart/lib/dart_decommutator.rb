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
require 'packet_log_entry'

class DartDecommutator
  include DartCommon

  # States for the Decommutation table reduced_state field
  INITIALIZING = 0 # New rows being created
  READY_TO_REDUCE = 1 # Once all new rows have been created
  REDUCED = 2 # After the data has been reduced

  # Wait 60s before giving up on the PacketConfig becoming ready
  PACKET_CONFIG_READY_TIMEOUT = 60

  def initialize(worker_id = 0, num_workers = 1)
    sync_targets_and_packets()
    @worker_id = worker_id
    @num_workers = num_workers
  end

  # Run forever looking for data to decommutate
  def run
    while true
      time_start = Time.now # Remember start time so we can throttle
      # Get all entries that are ready and decommutation hasn't started
      PacketLogEntry.where("decom_state = #{PacketLogEntry::NOT_STARTED} and ready = true").
                     # Mod the ID to allow distribution of effort, in_batches processes 1000 at a time
                     where("id % #{@num_workers} = #{@worker_id}").in_batches do |group|
        group.each do |ple|
          begin
            # TODO - Optimize and cache meta and system config and packet config lookup
            meta_ple = get_meta_ple(ple)
            next unless meta_ple
            system_meta = get_system_meta(ple, meta_ple)
            next unless system_meta
            system_config = get_system_config(ple, system_meta)
            next unless system_config
            packet = get_packet(ple)
            next unless packet
            packet_config = get_packet_config(ple, packet, system_config)
            next unless packet_config
            # If we timeout this code will simply exit the application
            wait_for_ready_packet_config(packet_config)
            decom_packet(ple, packet, packet_config.id)
          rescue => err
            Cosmos::Logger.error("PLE:#{ple.id}:ERROR")
            Cosmos::Logger.error(err.formatted)
          end
        end # each ple
      end # batches
      # Throttle to no faster than 1 Hz
      delta = Time.now - time_start
      sleep(1 - delta) if delta < 1 && delta > 0
    end
  rescue Interrupt
    Cosmos::Logger.info("Dart Worker Closing From Signal...")
  end

  protected

  def get_meta_ple(ple)
    if ple.meta_id != ple.id
      PacketLogEntry.find(ple.meta_id)
    else
      ple
    end
  rescue => err
    ple.decom_state = PacketLogEntry::NO_META_PLE
    ple.save
    Cosmos::Logger.error("PLE:#{ple.id}:#{ple.decom_state_string}")
    nil
  end

  def get_system_meta(ple, meta_ple)
    system_meta = read_packet_from_ple(meta_ple)
    return system_meta if system_meta

    ple.decom_state = PacketLogEntry::NO_META_PACKET
    ple.save
    Cosmos::Logger.error("PLE:#{ple.id}:#{ple.decom_state_string}")
    nil
  end

  def get_system_config(ple, system_meta)
    system_config_name = system_meta.read("CONFIG")
    system_config = SystemConfig.where("name = ?", system_config_name).first
    unless system_config
      begin
        # Try to create a new SystemConfig since it didn't exist
        system_config = SystemConfig.create(:name => system_config_name)
      rescue
        # Another thread probably already created it - Try to get it one more time
        system_config = SystemConfig.where("name = ?", system_config_name).first
      end
    end
    unless system_config
      ple.decom_state = PacketLogEntry::NO_SYSTEM_CONFIG
      ple.save
      Cosmos::Logger.error("PLE:#{ple.id}:#{ple.decom_state_string}")
      return nil
    end

    # Switch to this system_config
    begin
      switch_and_get_system_config(system_config_name)
    rescue
      Cosmos::Logger.error("Could not load system_config: #{system_config_name}")
      ple.decom_state = PacketLogEntry::NO_CONFIG
      ple.save
      Cosmos::Logger.error("PLE:#{ple.id}:#{ple.decom_state_string}")
      return nil
    end
    system_config
  end

  def get_packet(ple)
    packet = read_packet_from_ple(ple)
    return packet if packet

    ple.decom_state = PacketLogEntry::NO_PACKET
    ple.save
    Cosmos::Logger.error("PLE:#{ple.id}:#{ple.decom_state_string}")
    nil
  end

  def get_packet_config(ple, packet, system_config)
    packet_id = ple.packet_id
    packet_config = PacketConfig.where("packet_id = ? and name = ?", packet_id, packet.config_name).first
    return packet_config if packet_config

    # The PacketConfig didnt't exist so create one
    begin
      Cosmos::Logger.info("Creating PacketConfig: #{packet.config_name}...")
      packet_config = PacketConfig.create(:packet_id => packet_id, :name => packet.config_name, :first_system_config_id => system_config.id)
      setup_packet_config(packet, packet_id, packet_config)
      Cosmos::Logger.info("Successfully Created PacketConfig: #{packet.config_name}")
    rescue => err
      Cosmos::Logger.error(err.formatted)
      # Another thread probably already created it - Try to get it one more time
      packet_config = PacketConfig.where("packet_id = ? and name = ?", packet_id, packet.config_name).first
    end
    unless packet_config
      ple.decom_state = PacketLogEntry::NO_PACKET_CONFIG
      ple.save
      Cosmos::Logger.error("PLE:#{ple.id}:#{ple.decom_state_string}")
      return nil
    end
    packet_config
  end

  def wait_for_ready_packet_config(packet_config)
    first = true
    while !packet_config.ready
      if first
        ready_wait_start = Time.now
        Cosmos::Logger.info("Waiting for PacketConfig:#{packet_config.id}...")
        first = false
      end
      sleep(1)
      # Reload the attributes from the database
      packet_config.reload

      if (Time.now - ready_wait_start) > PACKET_CONFIG_READY_TIMEOUT
        Cosmos::Logger.fatal("Timeout waiting for ready on PacketConfig:#{packet_config.id}")
        exit(0)
      end
    end
  end

  def get_values(packet)
    values = []
    packet.sorted_items.each do |item|
      # We don't handle DERIVED items without explicit types and sizes
      if item.data_type == :DERIVED
        next unless well_defined_read_conversion(item)
      end
      if separate_raw_con?(item)
        values << packet.read_item(item, :RAW)
        values << packet.read_item(item, :CONVERTED)
      else
        values << packet.read_item(item, :RAW)
      end
    end
    values
  end

  def decom_packet(ple, packet, packet_config_id)
    # Mark the log entry IN_PROGRESS as we decommutate the data
    ple.decom_state = PacketLogEntry::IN_PROGRESS
    ple.save
    values = get_values(packet)

    table_index = 0
    rows = []
    # Create rows in the decommutation table model
    values.each_slice(MAX_COLUMNS_PER_TABLE) do |table_values|
      model = get_decom_table_model(packet_config_id, table_index)
      row = model.new
      row.time = ple.time
      row.ple_id = ple.id
      row.meta_id = ple.meta_id
      row.reduced_state = INITIALIZING
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
      row.reduced_state = READY_TO_REDUCE
      row.save
    end

    # The log entry has been decommutated, mark COMPLETE
    ple.decom_state = PacketLogEntry::COMPLETE
    ple.save
    Cosmos::Logger.debug("PLE:#{ple.id}:#{ple.decom_state_string}")
  end
end
