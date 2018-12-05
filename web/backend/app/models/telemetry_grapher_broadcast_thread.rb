# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/cmd_tlm_server/interface_thread'
require 'cosmos/interfaces/tcpip_client_interface'

# Thread used to gather telemetry in realtime and broadcast it
class TelemetryGrapherBroadcastThread < Cosmos::InterfaceThread
  def initialize(uuid)
    @uuid = uuid
    interface = Cosmos::TcpipClientInterface.new(
      'localhost', nil, Cosmos::System.ports['CTS_PREIDENTIFIED'], nil, 10.0, 'PREIDENTIFIED'
    )
    super(interface)
    self.identified_packet_callback = method(:received_packet_callback)
    #self.connection_success_callback = connection_success_callback
    #self.connection_failed_callback = connection_failed_callback
    #self.connection_lost_callback = connection_lost_callback
    #self.fatal_exception_callback = fatal_exception_callback

    @items = []
    @queue = Queue.new
    @process_thread = Thread.new do
      begin
        loop do
          packet = @queue.pop
          break unless packet
          process_packet(packet)
        end
      rescue Exception => error
        #if self.fatal_exception_callback
        #  self.fatal_exception_callback.call(error)
        #end
      end
    end
    start()
  end

  # item is a string formatted as "TGT PKT ITEM"
  def add_item(item)
    @items << item.split
  end

  def process_packet(packet)
    data = []
    @items.each do |tgt, pkt, item|
      if packet.target_name == tgt && packet.packet_name == pkt
        data << {'x' => (packet.read("RECEIVED_TIMESECONDS").to_f * 1000).to_i,
                 'y' => packet.read(item)}
      end
    end
    ActionCable.server.broadcast(@uuid, data) unless data.empty?
  end

  # Callback to the system definition when a packet is received
  def received_packet_callback(packet)
    @queue << packet.clone
  end

  # Kills the realtime thread
  def kill
    @queue << nil
    stop()
    Cosmos.kill_thread(self, @process_thread)
    @process_thread = nil
  end
end
