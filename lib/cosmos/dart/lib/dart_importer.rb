# encoding: ascii-8bit

# Copyright 2018 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'dart_common'

# Import COSMOS binary files into the DART database.
# This code must be run on the database server.
# The file to be imported should be placed in its final storage location.
# Note that files are imported in place with algorithms that attempt to prevent
# duplicate creation of Database entries.
class DartImporter
  include DartCommon

  # @param filename [String] Fully qualified filename to import
  # @param force [Boolean] Whether to reverify all packets in a log file
  #   are in the database or just abort if the first and last are found.
  def import(filename, force)
    Cosmos::Logger.level = Cosmos::Logger::INFO

    # Ensure all defined target and packets are in the database
    sync_targets_and_packets()

    dart_data_dir = File.expand_path(Cosmos::System.paths['DART_DATA'])
    directory = File.dirname(File.expand_path(filename))
    if directory != dart_data_dir
      Cosmos::Logger.fatal("Imported files must be in \"#{dart_data_dir}\"")
      Cosmos::Logger.fatal("  File is in: \"#{directory}\"")
      return 1
    end

    # Make sure this file isn't already imported
    packet_log = PacketLog.where("filename = ?", filename).first
    if packet_log
      Cosmos::Logger.warn("PacketLog already exists in database: #{filename}")
    end

    # Determine if this is a command or telemetry packet log
    begin
      plr = Cosmos::PacketLogReader.new
      plr.open(filename)
      if plr.log_type == :TLM
        is_tlm = true
      else
        is_tlm = false
      end
    rescue
      Cosmos::Logger.fatal("Unable to open #{filename}. Exiting...")
      return 1
    end

    # Check if first and last packet in the log are already in the database
    last_packet = plr.last
    first_packet = plr.first
    plr.close
    unless first_packet and last_packet
      Cosmos::Logger.fatal("No packets found in file. Exiting...")
      return 1
    end

    first_ple = find_packet_log_entry(first_packet, is_tlm)
    last_ple = find_packet_log_entry(last_packet, is_tlm)

    fast = false
    if first_ple and last_ple
      Cosmos::Logger.warn("First and Last Packet in File Already in Database.")
      if force
        Cosmos::Logger.warn("Reverifying all packets in database due to force...")
      else
        Cosmos::Logger.info("Complete")
        return 1
      end
    elsif !first_ple and !last_ple
      Cosmos::Logger.info("First and Last Packet in File not in database")

      # Check if time range of packets is not present in database
      ple = PacketLogEntry.where("time >= ? or time <= ?", first_packet.received_time, last_packet.received_time).first
      if !ple # Can go fast if not present at all
        Cosmos::Logger.info("  Fast Import Enabled...")
        fast = true
      end
    else
      Cosmos::Logger.warn("File partially in database. Will verify each packet before adding")
    end

    unless packet_log
      Cosmos::Logger.info("Creating PacketLog entry for file: #{filename}")
      packet_log = PacketLog.create(:filename => filename, :is_tlm => is_tlm)
    end

    # Read File and Create PacketLogEntries
    count = 0
    meta_id = nil
    plr.open(filename)
    data_offset = plr.bytes_read
    plr.each(filename) do |packet|
      target_name = packet.target_name
      target_name = 'UNKNOWN' unless target_name
      packet_name = packet.packet_name
      packet_name = 'UNKNOWN' unless packet_name

      target_id, packet_id = lookup_target_and_packet_id(target_name, packet_name, is_tlm)

      # If packets aren't found in the database we don't have to bother looking
      # for PacketLogEntrys in the database and can simply create new entries
      if fast
        ple = nil
      else # File is partially in the DB so see if the packet already exists
        ple = find_packet_log_entry(packet, is_tlm)
      end

      # No PacketLogEntry was found so create one from scratch
      unless ple
        ple = PacketLogEntry.new
        ple.target_id = target_id
        ple.packet_id = packet_id
        ple.time = packet.received_time
        ple.packet_log_id = packet_log.id
        ple.data_offset = data_offset
        ple.meta_id = meta_id
        ple.is_tlm = is_tlm
        ple.ready = true
        ple.save!
        count += 1

        # SYSTEM META packets are special in that their meta_id is their own
        # PacketLogEntry ID from the database. All other packets have meta_id
        # values which point back to the last SYSTEM META PacketLogEntry ID.
        if target_name == 'SYSTEM'.freeze and packet_name == 'META'.freeze
          # Need to update meta_id for this and all subsequent packets
          meta_id = ple.id
          ple.meta_id = meta_id
          ple.save!
        end
      else # A PacketLogEntry was found so this packet is skipped
        # If the packet is a SYSTEM META packet we keep track of the meta_id
        # for use in subsequent packets that aren't already in the database.
        if target_name == 'SYSTEM'.freeze and packet_name == 'META'.freeze
          # Need to update meta_id for subsequent packets
          meta_id = ple.id
        end
      end
      data_offset = plr.bytes_read
    end
    Cosmos::Logger.info("Added #{count} packet log entries to database")
    return 0 # Success code
  end
end
