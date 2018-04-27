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
    @ple_data = ""
    @sync_ple = nil
    if @log_type == :TLM
      @is_tlm = true
    else
      @is_tlm = false
    end

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
    # When we create a new file we write out any queued ple_data
    if @ple_data.length > 0
      @db_queue << @ple_data.clone
      @ple_data.clear
      @sync_count = 0
    end

    packet_log = PacketLog.new
    packet_log.filename = @filename.clone
    packet_log.is_tlm = @is_tlm
    packet_log.save!
    @packet_log_id = packet_log.id
    super(packet)
  end

  # Override the default pre write hook to pop a message on the queue which
  # will be processed by the database thread. This also writes out the log
  # files to disk periodically for use by other DART processes.
  def pre_write_entry_hook(packet)
    if @sync_ple
      @file.fsync
      @sync_ple.ready = true
      @sync_ple.save!
      @sync_ple = nil
      if @ple_data.length > 0
        @db_queue << @ple_data.clone
        @ple_data.clear
        @sync_count = 0
      end
    end

    # SYSTEM META packets are special in that their meta_id is their own
    # PacketLogEntry ID from the database. All other packets have meta_id
    # values which point back to the last SYSTEM META PacketLogEntry ID.
    target_id, packet_id = lookup_target_and_packet_id(packet.target_name, packet.packet_name, @is_tlm)
    if packet.target_name == 'SYSTEM'.freeze and packet.packet_name == 'META'.freeze
      ple = PacketLogEntry.new
      ple.target_id = target_id
      ple.packet_id = packet_id
      ple.time = packet.received_time
      ple.packet_log_id = @packet_log_id
      ple.data_offset = @file_size
      ple.meta_id = @meta_id
      ple.is_tlm = @is_tlm
      ple.ready = false
      ple.save!
      @meta_id = ple.id
      ple.meta_id = @meta_id
      ple.save!
      @sync_ple = ple
    else
      @sync_count += 1
      if @sync_count > @sync_count_limit
        @file.fsync
        @db_queue << @ple_data.clone
        @ple_data.clear
        @sync_count = 0
      end
      entry_time = Time.now.utc.to_s(:db)
      if @ple_data.length == 0
        @ple_data << "('#{entry_time}','#{entry_time}',#{target_id},#{packet_id},'#{packet.received_time.dup.utc.to_s(:db)}',#{@packet_log_id},#{@file_size},#{@meta_id},#{@is_tlm},true)"
      else
        @ple_data << ",('#{entry_time}','#{entry_time}',#{target_id},#{packet_id},'#{packet.received_time.dup.utc.to_s(:db)}',#{@packet_log_id},#{@file_size},#{@meta_id},#{@is_tlm},true)"
      end
    end
  end

  # Build the target / packet table lookup table and then wait on the queue
  # being populated by the pre_write_entry_hook thread to add rows to the
  # PacketLogEntry table. Each entry identifies a packet in the log file by
  # its target, packet, time, and data offset (among other things).
  def db_thread_body
    while true
      begin
        ple_data = @db_queue.pop
        return if @cancel_threads or ple_data.nil?
        ActiveRecord::Base.connection.execute("INSERT INTO packet_log_entries (created_at, updated_at, target_id, packet_id, time, packet_log_id, data_offset, meta_id, is_tlm, ready) VALUES #{ple_data}")
      rescue ThreadError
        # This can happen when the thread is killed
        return
      end
    end
  end
end
