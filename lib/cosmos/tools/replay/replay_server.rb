# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server'

module Cosmos

  class ReplayServer < CmdTlmServer

    # Start up the system by starting the JSON-RPC server, interfaces, routers,
    # and background tasks. Starts a thread to monitor all packets for
    # staleness so other tools (such as Packet Viewer or Telemetry Viewer) can
    # react accordingly.
    #
    # @param production (see #initialize)
    def start(production = false)
      # Prevent access to interfaces or packet_logging
      @interfaces = nil
      @packet_logging = nil

      System.telemetry # Make sure definitions are loaded by starting anything
      return unless @json_drb.nil?

      # Start DRb with access control
      @json_drb = JsonDRb.new
      @json_drb.acl = System.acl if System.acl

      @json_drb.method_whitelist = @api_whitelist
      begin
        @json_drb.start_service("localhost", System.ports['CTS_API'], self)
      rescue Exception
        raise FatalError.new("Error starting JsonDRb on port #{System.ports['CTS_API']}.\nPerhaps a Command and Telemetry Server is already running?")
      end

      @routers.add_preidentified('PREIDENTIFIED_ROUTER', System.instance.ports['CTS_PREIDENTIFIED'])
      System.telemetry.limits_change_callback = method(:limits_change_callback)
      @routers.start
    end

    # Properly shuts down the command and telemetry server by stoping the
    # JSON-RPC server, background tasks, routers, and interfaces. Also kills
    # the packet staleness monitor thread.
    def stop
      # Shutdown DRb
      @json_drb.stop_service
      @routers.stop
      @json_drb = nil
    end

    # Called when an item in any packet changes limits states.
    #
    # @param packet [Packet] Packet which has had an item change limits state
    # @param item [PacketItem] The item which has changed limits state
    # @param old_limits_state [Symbol] The previous state of the item. See
    #   {PacketItemLimits#state}
    # @param value [Object] The current value of the item
    # @param log_change [Boolean] Whether to log this limits change event
    def limits_change_callback(packet, item, old_limits_state, value, log_change)
      if log_change
        # Write to Server Messages that limits state has changed
        tgt_pkt_item_str = "#{packet.target_name} #{packet.packet_name} #{item.name} = #{value} is"
        time_string = ''
        time_string = packet.received_time.formatted << '  ' if packet.received_time

        case item.limits.state
        when :BLUE
          puts "<B>#{time_string}INFO: #{tgt_pkt_item_str} #{item.limits.state}"
        when :GREEN, :GREEN_LOW, :GREEN_HIGH
          puts "<G>#{time_string}INFO: #{tgt_pkt_item_str} #{item.limits.state}"
        when :YELLOW, :YELLOW_LOW, :YELLOW_HIGH
          puts "<Y>#{time_string}WARN: #{tgt_pkt_item_str} #{item.limits.state}"
        when :RED, :RED_LOW, :RED_HIGH
          puts "<R>#{time_string}ERROR: #{tgt_pkt_item_str} #{item.limits.state}"
        else
          puts "ERROR: #{tgt_pkt_item_str} UNKNOWN"
        end
      end

      post_limits_event(:LIMITS_CHANGE, [packet.target_name, packet.packet_name, item.name, old_limits_state, item.limits.state])
    end

  end # class ReplayServer

end # module Cosmos
