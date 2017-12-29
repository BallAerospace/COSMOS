require File.expand_path('../../config/environment', __FILE__)
require 'dart_common'

class DartPacketLogWriter < Cosmos::PacketLogWriter
  include DartCommon

  DEFAULT_SYNC_COUNT_LIMIT = 100

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

  def shutdown
    super()
    Cosmos.kill_thread(self, @db_thread)
  end

  def graceful_kill
    super()
    @db_queue << nil
  end

  protected

  def start_new_file_hook(packet)
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

  def pre_write_entry_hook(packet)
    @sync_count += 1
    if @sync_count > @sync_count_limit
      @file.fsync
      @sync_count = 0
    end
    @db_queue << [packet.target_name, packet.packet_name, packet.received_time, @file_size, @packet_log_id, @sync_count]
  end

  def db_thread_body
    if @log_type == :TLM
      is_tlm = true
    else
      is_tlm = false
    end
    build_lookups()

    while true
      begin
        target_name, packet_name, time, data_offset, packet_log_id, sync_count = @db_queue.pop
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

      if target_name == 'SYSTEM'.freeze and packet_name == 'META'.freeze
        # Need to update meta_id
        @meta_id = ple.id
        ple.meta_id = @meta_id
        ple.save!
      end

      @not_ready_ple_ids << ple.id
    end
  end
end
