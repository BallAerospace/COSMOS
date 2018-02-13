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

class DartTcpipServerInterface < Cosmos::TcpipServerInterface
  include DartCommon

  def initialize(write_timeout = 60, read_timeout = 5)
    Cosmos::Logger.level = Cosmos::Logger::INFO
    @dart_logging = DartLogging.new('dart_stream_server')

    port = Cosmos::System.ports['DART_STREAM']
    super(port, port, write_timeout, read_timeout, 'PREIDENTIFIED')
    @listen_address = Cosmos::System.listen_hosts['DART_STREAM']
    @plr_cache = {}
  end

  def connect
    @cancel_threads = false
    @read_queue.clear if @read_queue
    start_listen_thread(@read_port, true, true)
    @write_thread = nil
    @connected = true
  end

  def disconnect
    super
    @dart_logging.stop
  end

  def read_thread_body(interface)
    packet = interface.read
    return if !packet || @cancel_threads

    # Expect to receive a packet that is completed composed of a JSON object with the following fields
    # start_time_sec, start_time_usec
    # end_time_sec, end_time_usec
    # cmd_tlm = CMD, or TLM
    # packets [[target_name, packet_name], ...]
    json_data = packet.buffer(false)
    json_object = JSON.parse(json_data)
    Cosmos::Logger.info("Received Request: #{json_data}")
    start_time = Time.at(json_object['start_time_sec'], json_object['start_time_usec'])
    end_time = Time.at(json_object['end_time_sec'], json_object['end_time_usec'])
    cmd_tlm = json_object['cmd_tlm']
    packets = json_object['packets']
    meta_ids = json_object['meta_ids']
    if cmd_tlm and cmd_tlm.to_s.upcase == 'CMD'
      is_tlm = false
    else
      is_tlm = true
    end

    # Retrieve and stream out requested packets here
    pairs = []
    if packets
      packets.each do |target_name, packet_name|
        target = Target.where("name = ?", target_name.to_s.upcase).first
        if target
          packet = Packet.where("target_id = ? and name = ? and is_tlm = #{is_tlm}", target.id, packet_name.to_s.upcase).first
          if packet
            pairs << [target.id, packet.id]
          end
        end
      end
    end

    if pairs.length > 0
      where_clause = "("
      index = 0
      pairs.each do |target_id, packet_id|
        where_clause << " or " if index != 0
        where_clause << "(target_id = #{target_id} and packet_id = #{packet_id})"
        index += 1
      end
      where_clause << ")"
    else
      where_clause = "is_tlm = #{is_tlm}"
    end

    meta_ple = nil
    readers = {}
    begin
      packet_count = 0
      batch_size = 100
      batch_count = 0
      loop do
        ples = PacketLogEntry.where(where_clause)
        ples = ples.where(:meta_id => meta_ids) if meta_ids
        if start_time <= end_time
          ples = ples.where("time >= ?", start_time)
          ples = ples.where("time <= ?", end_time)
          ples = ples.order(time: :asc)
        else
          ples = ples.where("time >= ?", end_time)
          ples = ples.where("time <= ?", start_time)
          ples = ples.order(time: :desc)
        end
        ples = ples.limit(batch_size).offset(batch_count * batch_size)
        break if ples.length <= 0

        ples.each do |ple|
          if !meta_ple or ple.meta_id != meta_ple.id
            meta_ple = PacketLogEntry.find(ple.meta_id)
            meta_packet = read_packet_from_ple(meta_ple)
            if meta_packet
              begin
                interface.write(meta_packet)
                packet_count += 1
              rescue Exception
                Cosmos::Logger.error("Request ended with meta packet write error")
                break
              end
            else
              Cosmos::Logger.error("No Meta Packet Read: #{meta_ple.inspect}")
            end
          end

          if meta_ple.id != ple.id
            packet = read_packet_from_ple(ple)
            if packet
              begin
                interface.write(packet)
                packet_count += 1
              rescue Exception
                Cosmos::Logger.error("Request ended with write error")
                break
              end
            else
              Cosmos::Logger.error("No Packet Read: #{ple.inspect}")
            end
          end
        end

        batch_count += 1
      end
      Cosmos::Logger.info("Request fully served #{packet_count} packets")
    ensure
      readers.each { |_, reader| reader.close }
    end
  end
end
