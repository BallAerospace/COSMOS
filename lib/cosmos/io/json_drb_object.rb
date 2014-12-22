# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Lesser General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'thread'
require 'socket'
require 'json'
require 'drb/acl'
require 'drb/drb'
require 'cosmos/io/json_drb'

module Cosmos

  # Used to forward all method calls to the remote server object. Before using
  # this class ensure the remote service has been started in the server class:
  #
  #   json = JsonDrb.new
  #   json.start_service('127.0.0.1', 7777, self)
  #
  # Now the JsonDRbObject can be used to call server methods directly:
  #
  #   server = JsonDRbObject('127.0.0.1', 7777)
  #   server.cmd(*args)
  #
  class JsonDRbObject
    # @param hostname [String] The name of the machine which has started
    #   the JSON service
    # @param port [Integer] The port number of the JSON service
    def initialize(hostname, port)
      hostname = '127.0.0.1' if (hostname.to_s.upcase == 'LOCALHOST')
      begin
        @addr = Socket.pack_sockaddr_in(port, hostname)
      rescue => error
        if error.message =~ /getaddrinfo/
          raise "Invalid hostname: #{hostname}"
        else
          raise error
        end
      end
      @hostname = hostname
      @port = port
      @mutex = Mutex.new
      @socket = nil
      @id = 0
      @request_in_progress = false
    end

    # Disconnects from the JSON server
    def disconnect
      @socket.close if @socket and !@socket.closed?
    end

    # Forwards all method calls to the remote service.
    #
    # @param method_name [Symbol] Name of the method to call
    # @param method_params [Array] Array of parameters to pass to the method
    # @return The result of the method call. If the method raises an exception
    #   the same exception is also raised. If something goes wrong with the
    #   protocol a DRb::DRbConnError exception is raised.
    def method_missing(method_name, *method_params)
      @mutex.synchronize do
        first_try = true
        loop do
          if !@socket or @socket.closed? or @request_in_progress
            if @request_in_progress
              @socket.close if @socket and !@socket.closed?
              @socket = nil
              @request_in_progress = false
            end
            begin
              @socket = TCPSocket.new(@hostname, @port)
              @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
            rescue => e
              raise DRb::DRbConnError, e.message
            end
          end

          request = JsonRpcRequest.new(method_name, method_params, @id)
          @id += 1

          request_data = request.to_json(:allow_nan => true)
          begin
            @request_in_progress = true
            STDOUT.puts "Request:\n" if JsonDRb.debug?
            STDOUT.puts request_data if JsonDRb.debug?
            JsonDRb.send_data(@socket, request_data)
            response_data = JsonDRb.receive_message(@socket, '')
            STDOUT.puts "\nResponse:\n" if JsonDRb.debug?
            STDOUT.puts response_data if JsonDRb.debug?
            @request_in_progress = false
          rescue => e
            @socket.close if @socket and !@socket.closed?
            @socket = nil
            if first_try
              first_try = false
              next
            else
              raise DRb::DRbConnError, e.message, e.backtrace
            end
          end

          if response_data
            response = JsonRpcResponse.from_json(response_data)
            if JsonRpcErrorResponse === response
              if response.error.data
                raise Exception.from_hash(response.error.data)
              else
                raise "JsonDRb Error (#{response.error.code}): #{response.error.message}"
              end
            else
              return response.result
            end
          else
            # Socket was closed by server
            @socket.close if @socket and !@socket.closed?
            @socket = nil
            if first_try
              first_try = false
              next
            else
              # Socket already closed by receive_message
              raise DRb::DRbConnError, "Socket closed by server"
            end
          end
        end # loop
      end
    end
  end

end # module Cosmos
