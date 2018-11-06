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

module Cosmos

  # Thread used to gather telemetry in realtime and process it using a TabbedPlotsDefinition
  class TabbedPlotsRealtimeThread < InterfaceThread
    # Create a new TabbedPlotsRealtimeThread
    def initialize(tabbed_plots_config, connection_success_callback = nil, connection_failed_callback = nil, connection_lost_callback = nil, fatal_exception_callback = nil, replay_mode = false)
      if replay_mode
        interface = TcpipClientInterface.new(System.connect_hosts['REPLAY_PREIDENTIFIED'], nil, System.ports['REPLAY_PREIDENTIFIED'], nil, nil, 'PREIDENTIFIED')
      else
        interface = TcpipClientInterface.new(System.connect_hosts['CTS_PREIDENTIFIED'], nil, System.ports['CTS_PREIDENTIFIED'], nil, tabbed_plots_config.cts_timeout, 'PREIDENTIFIED')
      end
      super(interface)

      @queue = Queue.new
      @tabbed_plots_config = tabbed_plots_config

      # Connect callbacks
      self.identified_packet_callback = method(:received_packet_callback)
      self.connection_success_callback = connection_success_callback
      self.connection_failed_callback = connection_failed_callback
      self.connection_lost_callback = connection_lost_callback
      self.fatal_exception_callback = fatal_exception_callback

      @process_thread = Thread.new do
        begin
          loop do
            packet = @queue.pop
            break unless packet
            @tabbed_plots_config.process_packet(packet)
          end
        rescue Exception => error
          if self.fatal_exception_callback
            self.fatal_exception_callback.call(error)
          end
        end
      end

      # Start interface thread
      start()
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

    def graceful_kill
      # Allow the callbacks a chance to update the GUI so that they can die gracefully
      if defined? Qt and Thread.current == Thread.main
        5.times do
          Qt::CoreApplication.instance.processEvents
          sleep(0.05)
        end
      end
    end
  end
end
