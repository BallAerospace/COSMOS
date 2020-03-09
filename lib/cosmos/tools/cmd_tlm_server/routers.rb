# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/cmd_tlm_server/connections'
require 'cosmos/tools/cmd_tlm_server/router_thread'
require 'cosmos/interfaces/tcpip_server_interface'

module Cosmos

  # Controls the routers as defined in the Command/Telemetry configuration
  # file. Routers are just interfaces which receive command packets from their
  # remote connection and send them out to their interfaces. They receive
  # telemetry packets from their interfaces and send them to their remote
  # connections. This allows them to be intermediaries between an external
  # client and the actual device.
  class Routers < Connections
    # @param cmd_tlm_server_config [CmdTlmServerConfig] The configuration which
    #   defines all the routers
    def initialize(cmd_tlm_server_config)
      super(:ROUTERS, cmd_tlm_server_config)
    end

    # Adds a Preidentified router to the system with given name and port.
    # All interfaces defined by the Command/Telemetry configuration are
    # directed to this router for both commands and telemetry.
    #
    # @param router_name [String] Name of the router
    # @param port [Integer] Port to pass to the {TcpipServerInterface}
    def add_preidentified(router_name, port)
      router_name = router_name.upcase
      router = TcpipServerInterface.new(port, port, 10.0, nil, 'PREIDENTIFIED')
      router.name = router_name
      router.disable_disconnect = true
      if CmdTlmServer.mode == :CMD_TLM_SERVER
        router.set_option('LISTEN_ADDRESS', [System.listen_hosts['CTS_PREIDENTIFIED']])
      else
        router.set_option('LISTEN_ADDRESS', [System.listen_hosts['REPLAY_PREIDENTIFIED']])
      end
      router.set_option('AUTO_SYSTEM_META', [true])
      @config.routers[router_name] = router
      @config.interfaces.each do |interface_name, interface|
        router.interfaces << interface
        interface.routers << router
      end
      router
    end

    # Adds a Preidentified command router to the system with given name and port.
    # All interfaces defined by the Command/Telemetry configuration are
    # directed to this router to output commands
    #
    # @param cmd_router_name [String] Name of the command router
    # @param port [Integer] Port to pass to the {TcpipServerInterface}
    def add_cmd_preidentified(cmd_router_name, port)
      cmd_router_name = cmd_router_name.upcase
      cmd_router = TcpipServerInterface.new(port, nil, 10.0, nil, 'PREIDENTIFIED')
      cmd_router.name = cmd_router_name
      cmd_router.disable_disconnect = true
      if CmdTlmServer.mode == :CMD_TLM_SERVER
        cmd_router.set_option('LISTEN_ADDRESS', [System.listen_hosts['CTS_CMD_ROUTER']])
      else
        cmd_router.set_option('LISTEN_ADDRESS', [System.listen_hosts['REPLAY_CMD_ROUTER']])
      end
      cmd_router.set_option('AUTO_SYSTEM_META', [true])
      @config.routers[cmd_router_name] = cmd_router
      @config.interfaces.each do |interface_name, interface|
        interface.cmd_routers << cmd_router
      end
      cmd_router
    end

    # Recreate a router with new initialization parameters
    #
    # @param router_name [String] Name of the router
    # @param params [Array] Array of parameters to pass to the router
    #   constructor
    def recreate(router_name, *params)
      router = @config.routers[router_name.upcase]
      raise "Unknown router: #{router_name}" unless router

      # Build New Router
      new_router = router.class.new(*params)
      router.copy_to(new_router)

      # Remove old router and add new to each interface
      router.interfaces.each do |interface|
        interface.routers.delete(router)
        interface.routers << new_router
      end

      # Replace interface in @interfaces array
      @config.routers[router_name.upcase] = new_router

      # Make sure there is no thread
      stop_thread(router)

      return new_router
    end

    # Get info about an router by name
    #
    # @return [Array<String, Numeric, Numeric, Numeric, Numeric, Numeric,
    #   Numeric, Numeric>] Array containing \[state, num_clients,
    #   write_queue_size, read_queue_size, bytes_written, bytes_read,
    #   read_count, write_count] for the interface
    def get_info(router_name)
      router = @config.routers[router_name.upcase]
      raise "Unknown router: #{router_name}" unless router

      return [state(router_name),      router.num_clients,
              router.write_queue_size, router.read_queue_size,
              router.bytes_written,    router.bytes_read,
              router.read_count,       router.write_count]
    end

    protected

    # Start an router's packet reading thread
    def start_thread(router)
      Logger.info "Creating thread for router #{router.name}"
      router_thread = RouterThread.new(router)
      router_thread.start
    end

    # Stop an router's packet reading thread
    def stop_thread(router)
      if router.thread
        Logger.info "Killing thread for router #{router.name}"
        to_stop = router.thread
        router.thread = nil
        to_stop.stop
      end
    end

  end # class Routers

end # module Cosmos
