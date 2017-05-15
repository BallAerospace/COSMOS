# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/interfaces/tcpip_server_interface'

module Cosmos

  # Abstract base class for {Routers} and {Interfaces}. Since Routers are just
  # Interfaces they share a lot of responsibilies which are captured here.
  class Connections
    # @param cmd_tlm_server_config [CmdTlmServerConfig] The configuration which
    #   defines all the connections
    def initialize(type, cmd_tlm_server_config)
      @config = cmd_tlm_server_config
      if type == :INTERFACES
        @connections = @config.interfaces
        @keyword = "interface"
      elsif type == :ROUTERS
        @connections = @config.routers
        @keyword = "router"
      else
        raise "Unknown type: #{type}. Must be :INTERFACES or :ROUTERS."
      end
    end

    # Creates a thread for each connection which sends all commands received out on
    # the connection interfaces
    def start
      @connections.each do |connection_name, connection|
        connect(connection_name) if connection.connect_on_startup
      end
    end

    # Stop connections by disconnecting the interface and killing the thread
    def stop
      @connections.each do |connection_name, connection|
        disconnect(connection_name)
        stop_raw_logging(connection_name)
      end
    end

    # Connect a connection by name
    #
    # @param connection_name [String] Name of the connection
    # @param params [Array] Array of parameters to be passed to the {#recreate}
    #   method. Pass nothing to start the connection for the first time.
    def connect(connection_name, *params)
      connection = @connections[connection_name.upcase]
      raise "Unknown #{@keyword}: #{connection_name}" unless connection

      if params.empty?
        start_thread(connection) unless connection.thread
      else
        disconnect(connection_name)
        connection = recreate(connection_name, *params)
        start_thread(connection)
      end
    end

    # Recreate an interface with new initialization parameters. Must be
    # implemented by a subclass.
    #
    # @param connection_name [String] Name of the connection
    # @param params [Array] Array of parameters to pass to the connection
    #   constructor
    def recreate(connection_name, *params)
      raise "Connections recreate method not implemented"
    end

    # Disconnect a connection by name
    #
    # @param connection_name [String] Name of the connection
    def disconnect(connection_name)
      connection = @connections[connection_name.upcase]
      raise "Unknown #{@keyword}: #{connection_name}" unless connection

      stop_thread(connection)
      Logger.info "Disconnected from #{@keyword} #{connection_name.upcase}"
    end

    # Get the state of a connection by name
    #
    # @return [String] Either 'CONNECTED', 'ATTEMPTING', or 'DISCONNECTED'.
    def state(connection_name)
      connection = @connections[connection_name.upcase]
      raise "Unknown #{@keyword}: #{connection_name}" unless connection

      if connection.connected?
        return 'CONNECTED'
      elsif connection.thread
        return 'ATTEMPTING'
      else
        return 'DISCONNECTED'
      end
    end

    # @return [Array<String>] The names of all the connections
    def names
      names = []
      @connections.each do |connection_name, connection|
        names << connection_name
      end
      return names.sort
    end

    # Clears the bytes written, bytes read, write count, and read count from
    # each of the connections.
    def clear_counters
      @connections.each do |connection_name, connection|
        connection.bytes_written = 0
        connection.bytes_read = 0
        connection.write_count = 0
        connection.read_count = 0
      end
    end

    # @return [Hash<String, Interface>] All the connections
    def all
      @connections
    end

    # Start raw logging on a connection by name
    #
    # @param connection_name [String] Name of the connection
    def start_raw_logging(connection_name = 'ALL')
      connection_name_upcase = connection_name.upcase
      if connection_name == 'ALL'
        @connections.each do |_, connection|
          connection.start_raw_logging
        end
      else
        connection = @connections[connection_name_upcase]
        raise "Unknown #{@keyword}: #{connection_name}" unless connection
        connection.start_raw_logging
      end
    end

    # Stop raw logging on a connection by name
    #
    # @param connection_name [String] Name of the connection
    def stop_raw_logging(connection_name = 'ALL')
      connection_name_upcase = connection_name.upcase
      if connection_name == 'ALL'
        @connections.each do |_, connection|
          connection.stop_raw_logging
        end
      else
        connection = @connections[connection_name_upcase]
        raise "Unknown #{@keyword}: #{connection_name}" unless connection
        connection.stop_raw_logging
      end
    end

    protected

    # Start an connection's packet reading thread
    def start_thread(connection)
      raise "Connections start_thread method not implemented"
    end

    # Stop an connection's packet reading thread
    def stop_thread(connection)
      raise "Connections stop_thread method not implemented"
    end

  end # class Connections

end # module Cosmos
