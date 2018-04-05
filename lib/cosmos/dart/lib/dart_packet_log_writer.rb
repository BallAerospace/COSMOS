# encoding: ascii-8bit

# Copyright 2018 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'dart_common'

# Writes all packets to a log file for use by the DART database.
# The PacketLog table hold the binary file name.
# As each packet is written to disk the location of the packet
# is recorded in the PacketLogEntry table for quick access.
class DartPacketLogWriter < Cosmos::PacketLogWriter
  include DartCommon

  DEFAULT_SYNC_COUNT_LIMIT = 100

  # Initialize the database by synchronizing all known targets and
  # packet names to the Target and Packet tables. Start the thread
  # which updates the PacketLogEntry table when new packets arrive.
  def initialize(*args)
    super(*args)
    @packet_log_id = nil
    @meta_id = nil
    @db_queue = Queue.new
    @sync_count = 0
    @sync_count_limit = DEFAULT_SYNC_COUNT_LIMIT
    @not_ready_ple_ids = []

    sync_targets_and_packets()

    @db_thread = Cosmos.safe_thread("Database packet log entries") do
      db_thread_body()
    end
  end

  # Kill the database update thread
  def shutdown
    super()
    Cosmos.kill_thread(self, @db_thread)
  end

  # Kick the database update thread to allow it to quit
  def graceful_kill
    super()
    @db_queue << nil
  end

  protected

  # Override the default new file hook to create a PacketLog entry in the database
  def start_new_file_hook(packet)
    # When we create a new file we mark any existing PLEs ready
    PacketLogEntry.where("id" => @not_ready_ple_ids).update_all(ready: true)
    @not_ready_ple_ids.clear
    @sync_count = 0

    packet_log = PacketLog.new
    packet_log.filename = @filename.clone
    if @log_type == :TLM
      packet_log.is_tlm = true
    else
      packet_log.is_tlm = false
    end
    packet_log.save!
    @packet_log_id = packet_log.id
    super(packet)
  end

  # Override the default pre write hook to pop a message on the queue which
  # will be processed by the database thread. This also writes out the log
  # files to disk periodically for use by other DART processes.
  def pre_write_entry_hook(packet)
    @sync_count += 1
    if @sync_count > @sync_count_limit
      @file.fsync
      @sync_count = 0
    end
    @db_queue << [packet.target_name, packet.packet_name, packet.received_time, @file_size, @packet_log_id, @sync_count]
  end

  # Build the target / packet table lookup table and then wait on the queue
  # being populated by the pre_write_entry_hook thread to add rows to the
  # PacketLogEntry table. Each entry identifies a packet in the log file by
  # its target, packet, time, and data offset (among other things).
  def db_thread_body
    if @log_type == :TLM
      is_tlm = true
    else
      is_tlm = false
    end

    while true
      begin
        target_name, packet_name, time, data_offset, packet_log_id, sync_count = @db_queue.pop
        # Every time the sync_count resets by the pre_write_entry_hook the file
        # is written out to disk. Thus we mark all the PacketLogEntrys to ready
        # since we know the packets have been written to disk.
        if sync_count == 0 or sync_count.nil?
          PacketLogEntry.where("id" => @not_ready_ple_ids).update_all(ready: true)
          @not_ready_ple_ids.clear
        end
        return if @cancel_threads or sync_count.nil?
      rescue ThreadError
        # This can happen when the thread is killed
        return
      end

      target_id, packet_id = lookup_target_and_packet_id(target_name, packet_name, is_tlm)

      ple = PacketLogEntry.new
      ple.target_id = target_id
      ple.packet_id = packet_id
      ple.time = time
      ple.packet_log_id = packet_log_id
      ple.data_offset = data_offset
      ple.meta_id = @meta_id
      ple.is_tlm = is_tlm
      ple.ready = false
      ple.save!

      # SYSTEM META packets are special in that their meta_id is their own
      # PacketLogEntry ID from the database. All other packets have meta_id
      # values which point back to the last SYSTEM META PacketLogEntry ID.
      if target_name == 'SYSTEM'.freeze and packet_name == 'META'.freeze
        # Need to update meta_id for this and all subsequent packets
        @meta_id = ple.id
        ple.meta_id = @meta_id
        ple.save!
      end
      # Remember this new PacketLogEntry so we can mark it ready later
      @not_ready_ple_ids << ple.id
    end
  end
end
