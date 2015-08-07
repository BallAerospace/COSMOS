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
    FAST_READ = (RUBY_VERSION > "2.1")

    @@debug = false

    # @return [Integer] The number of JSON-RPC requests processed
    attr_accessor :request_count
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
      @client_sockets = []
      @client_threads = []
      @client_pipe_writers = []
      @client_mutex = Mutex.new
      @thread_reader, @thread_writer = IO.pipe
    end

    # Returns the number of connected clients
    # @return [Integer] The number of connected clients
    def num_clients
      @client_threads.length
    end

    # Stops the DRb service by closing the socket and the processing thread
    def stop_service
      Cosmos.kill_thread(self, @thread)
      @thread = nil
      Cosmos.close_socket(@listen_socket)
      @listen_socket = nil
      client_threads = nil
      @client_mutex.synchronize do
        @client_sockets.each do |client_socket|
          Cosmos.close_socket(client_socket)
        end
        @client_pipe_writers.each do |client_pipe_writer|
          client_pipe_writer.write('.')
        end
        client_threads = @client_threads.clone
      end

      # This cannot be inside of the client_mutex or the threads will not
      # be able to shutdown because they will stick on the client_mutex
      client_threads.each do |client_thread|
        Cosmos.kill_thread(self, client_thread)
      end

      @client_mutex.synchronize do
        @client_threads.clear
        @client_sockets.clear
        @client_pipe_writers.clear
      end
    end

    # Gracefully kill the thread
    def graceful_kill
      @thread_writer.write('.') if @thread
    end

    # @param hostname [String] The host to start the service on
    # @param port [Integer] The port number to listen for connections
    # @param object [Object] The object to send the DRb requests to. This
    #   object must either include the Cosmos::Script module or be the
    #   CmdTlmServer.
    def start_service(hostname = nil, port = nil, object = nil)
      if hostname and port and object
        @thread_reader, @thread_writer = IO.pipe
        @object = object
        hostname = '127.0.0.1'.freeze if (hostname.to_s.upcase == 'LOCALHOST'.freeze)

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
              begin
                socket = @listen_socket.accept_nonblock
              rescue Errno::EAGAIN, Errno::ECONNABORTED, Errno::EINTR, Errno::EWOULDBLOCK
                read_ready, _ = IO.select([@listen_socket, @thread_reader])
                if read_ready and read_ready.include?(@thread_reader)
                  # Thread should be killed
                  break
                else
                  retry
                end
              end

              if @acl and !@acl.allow_socket?(socket)
                Cosmos.close_socket(socket)
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
    # @param pipe_reader [IO.pipe] Used to break out of select
    # @return [String] The request message
    def self.receive_message(socket, data, pipe_reader)
      self.get_at_least_x_bytes_of_data(socket, data, 4, pipe_reader)
      if data.length >= 4
        length = data[0..3].unpack('N'.freeze)[0]
        data.replace(data[4..-1])
      else
        return nil
      end

      self.get_at_least_x_bytes_of_data(socket, data, length, pipe_reader)
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
    # @param pipe_reader [IO.pipe] Used to break out of select
    #   before returning
    def self.get_at_least_x_bytes_of_data(socket, current_data, required_num_bytes, pipe_reader)
      while (current_data.length < required_num_bytes)
        if FAST_READ
          data = socket.read_nonblock(65535, exception: false)
          raise EOFError, 'end of file reached' unless data
          if data == :wait_readable
            IO.fast_select([socket, pipe_reader], nil, nil, nil)
          else
            current_data << data
          end
        else
          begin
            current_data << socket.read_nonblock(65535)
          rescue IO::WaitReadable
            IO.fast_select([socket, pipe_reader], nil, nil, nil)
          end
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
      data_to_send = [data.length].pack('N'.freeze) << data.clone

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
        pipe_reader, pipe_writer = IO.pipe
        @client_mutex.synchronize do
          @client_sockets << my_socket
          @client_threads << Thread.current
          @client_pipe_writers << pipe_writer
        end

        data = ''

        begin
          while true
            begin
              request_data = JsonDRb.receive_message(my_socket, data, pipe_reader)
              start_time = Time.now
              @request_count += 1
            rescue Errno::ECONNRESET, Errno::ECONNABORTED, Errno::ENOTSOCK
              # Socket was closed
              break
            end
            if request_data
              break unless process_request(request_data, my_socket, start_time)
            else
              # Socket was closed by client
              break
            end
          end
        rescue Exception => error
          Logger.error "JsonDrb client thread unexpectedly died.\n#{error.formatted}"
        end

        @client_mutex.synchronize do
          Cosmos.close_socket(my_socket)
          @client_sockets.delete(my_socket)
          @client_threads.delete(Thread.current)
          @client_pipe_writers.delete(pipe_writer)
        end
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

