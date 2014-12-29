# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Lesser General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'thread'
require 'socket'
require 'json'
require 'drb/acl'
require 'drb/drb'
require 'set'
require 'cosmos/io/json_rpc'

module Cosmos

  # JsonDRb implements the JSON-RPC 2.0 Specification to provide an interface
  # for both internal and external tools to access the COSMOS server. It
  # provides methods to install an access control list to control access to the
  # API. It also limits the available methods to a known list of allowable API
  # methods.
  class JsonDRb
    MINIMUM_REQUEST_TIME = 0.0001

    @@debug = false

    # @return [Integer] The number of JSON-RPC requests processed
    attr_accessor :request_count
    # @return [Integer] The number of clients currently connected to the server
    attr_accessor :num_clients
    # @return [Array<String>] List of methods that should be allowed
    attr_accessor :method_whitelist
    # @return [ACL] The access control list
    attr_accessor :acl

    def initialize
      @listen_socket = nil
      @thread = nil
      @acl = nil
      @object = nil
      @method_whitelist = nil
      @request_count = 0
      @request_times = []
      @request_times_index = 0
      @request_mutex = Mutex.new
      @num_clients = 0
    end

    # Stops the DRb service by closing the socket and the processing thread
    def stop_service
      @thread.kill if @thread
      @thread = nil
      @listen_socket.close if @listen_socket and !@listen_socket.closed?
      @listen_socket = nil
    end

    # @param hostname [String] The host to start the service on
    # @param port [Integer] The port number to listen for connections
    # @param object [Object] The object to send the DRb requests to. This
    #   object must either include the Cosmos::Script module or be the
    #   CmdTlmServer.
    def start_service(hostname = nil, port = nil, object = nil)
      if hostname and port and object
        @object = object
        hostname = '127.0.0.1' if (hostname.to_s.upcase == 'LOCALHOST')

        # Create a socket to accept connections from clients
        begin
          @listen_socket = TCPServer.new(hostname, port)
          @listen_socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1) unless Kernel.is_windows?
        # The address is use error is pretty typical if an existing
        # CmdTlmServer is running so explicitly rescue this
        rescue Errno::EADDRINUSE
          raise "Error binding to port #{port}.\n" +
                "Either another application is using this port\n" +
                "or the operating system is being slow cleaning up.\n" +
                "Make sure all sockets/streams are closed in all applications,\n" +
                "wait 1 minute and try again."
        # Something else went wrong which is fatal
        rescue => error
          Logger.error "JsonDRb listen thread unable to be created.\n#{error.formatted}"
          Cosmos.handle_fatal_exception(error)
        end

        # Start the listen thread which accepts connections
        @thread = Thread.new do
          begin
            while true
              socket = @listen_socket.accept()
              if @acl and !@acl.allow_socket?(socket)
                socket.close
                next
              end
              # Create new thread for new connection
              create_client_thread(socket)
            end
          rescue Exception => error
            Logger.error "JsonDRb listen thread unexpectedly died.\n#{error.formatted}"
            Cosmos.handle_fatal_exception(error)
          end
        end
      elsif hostname or port or object
        raise "0 or 3 parameters must be given"
      else
        # Client - Noop
      end
    end

    # @return [Thread] The server thread listening for incoming requests
    def thread
      @thread
    end

    # Adds a request time to the list. A request time consists of the amount of
    # time to receive the request, process it, and send the response. These
    # times are used by the {#average_request_time} method to calculate an
    # average request time.
    #
    # @param request_time [Float] Time in seconds for the data transmission
    def add_request_time(request_time)
      @request_mutex.synchronize do
        request_time = MINIMUM_REQUEST_TIME if request_time < MINIMUM_REQUEST_TIME
        @request_times[@request_times_index] = request_time
        @request_times_index += 1
        @request_times_index = 0 if @request_times_index >= 100
      end
    end

    # @return [Float] The average time in seconds for a JSON DRb request to be
    #   processed and the response sent.
    def average_request_time
      avg = 0
      @request_mutex.synchronize do
        avg = @request_times.mean
      end
      avg
    end

    # @param socket [Socket] The socket to the client
    # @param data [String] Binary data which has already been read from the
    #   socket.
    # @return [String] The request message
    def self.receive_message(socket, data)
      self.get_at_least_x_bytes_of_data(socket, data, 4)
      if data.length >= 4
        length = data[0..3].unpack('N')[0]
        data.replace(data[4..-1])
      else
        return nil
      end

      self.get_at_least_x_bytes_of_data(socket, data, length)
      if data.length >= length
        message = data[0..(length - 1)]
        data.replace(data[length..-1])
        return message
      else
        return nil
      end
    end

    # @param socket [Socket] The socket to the client
    # @param current_data [String] Binary data read from the socket
    # @param required_num_bytes [Integer] The minimum number of bytes to read
    #   before returning
    def self.get_at_least_x_bytes_of_data(socket, current_data, required_num_bytes)
      while (current_data.length < required_num_bytes)
        begin
          data = socket.recv_nonblock(65535)
          if data.length == 0
            current_data.replace('')
            return
          end
          current_data << data
        rescue Errno::EAGAIN, Errno::EWOULDBLOCK
          IO.fast_select([socket], nil, nil, nil)
          retry
        end
      end
    end

    # @param socket [Socket] The socket to the client
    # @param data [String] Binary data to send to the socket
    # @param send_timeout [Float] The number of seconds to wait for the send to
    #   complete
    def self.send_data(socket, data, send_timeout = 10.0)
      num_bytes_to_send = data.length + 4
      total_bytes_sent = 0
      bytes_sent = 0
      data_to_send = [data.length].pack('N') << data.clone

      loop do
        begin
          bytes_sent = socket.write_nonblock(data_to_send[total_bytes_sent..-1])
        rescue Errno::EAGAIN, Errno::EWOULDBLOCK
          result = IO.fast_select(nil, [socket], nil, send_timeout)
          if result
            retry
          else
            raise Timeout::Error, "Send Timeout"
          end
        end
        total_bytes_sent += bytes_sent
        break if total_bytes_sent >= num_bytes_to_send
      end
    end

    # @return [Boolean] Whether debug messages are enabled
    def self.debug?
      @@debug
    end

    # @param value [Boolean] Whether to enable debug messages
    def self.debug=(value)
      @@debug = value
    end

    protected

    # Creates a new Thread to service the JSON DRb requests from the client.
    #
    # @param socket [Socket] The socket which the server accepted from the
    #   client.
    def create_client_thread(socket)
      socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, 1)

      Thread.new(socket) do |my_socket|
        @num_clients += 1
        data = ''
        begin
          while true
            begin
              request_data = JsonDRb.receive_message(my_socket, data)
              start_time = Time.now
              @request_count += 1
            rescue Errno::ECONNRESET, Errno::ECONNABORTED
              # Socket was closed
              break
            end
            if request_data
              break unless process_request(request_data, my_socket, start_time)
            else
              # Socket was closed by client
              my_socket.close unless my_socket.closed?
              break
            end
          end
        rescue Exception => error
          Logger.error "JsonDrb client thread unexpectedly died.\n#{error.formatted}"
        end
        @num_clients -= 1
      end
    end

    # Process the JSON request data, execute the method, and send the response.
    #
    # @param request_data [String] The JSON encoded request
    # @param my_socket [Socket] The socket to send the response out on
    # @param start_time [Time] The time when the initial request was received
    def process_request(request_data, my_socket, start_time)
      STDOUT.puts request_data if JsonDRb.debug?
      begin
        request = JsonRpcRequest.from_json(request_data)
        response = nil

        if (@method_whitelist and @method_whitelist.include?(request.method)) or
           (!@method_whitelist and !JsonRpcRequest::DANGEROUS_METHODS.include?(request.method))
          begin
            result = @object.send(request.method.intern, *request.params)
            if request.id
              response = JsonRpcSuccessResponse.new(result, request.id)
            end
          rescue Exception => error
            if request.id
              if NoMethodError === error
                response = JsonRpcErrorResponse.new(
                  JsonRpcError.new(-32601, "Method not found", error), request.id)
              elsif ArgumentError === error
                response = JsonRpcErrorResponse.new(
                  JsonRpcError.new(-32602, "Invalid params", error), request.id)
              else
                response = JsonRpcErrorResponse.new(
                  JsonRpcError.new(-1, error.message, error), request.id)
              end
            end
          end
        else
          if request.id
            response = JsonRpcErrorResponse.new(
              JsonRpcError.new(-1, "Cannot call unauthorized methods"), request.id)
          end
        end
        process_response(response, my_socket, start_time) if response
      rescue => error
        response = JsonRpcErrorResponse.new(JsonRpcError.new(-32600, "Invalid Request", error), nil)
        process_response(response, my_socket, start_time)
      end
      true
    end

    def process_response(response, socket, start_time)
      response_data = response.to_json(:allow_nan => true)
      STDOUT.puts response_data if JsonDRb.debug?
      JsonDRb.send_data(socket, response_data)
      end_time = Time.now
      request_time = end_time - start_time
      add_request_time(request_time)
    rescue
      # Socket was closed?
      return false
    end

  end
end

