# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'thread'
require 'socket'
require 'json'
# require 'drb/acl'
require 'drb/drb'
require 'set'
require 'openc3/io/json_rpc'
require 'openc3/io/json_drb_rack'
require 'rack/handler/puma'

# Add methods to the Puma::Launcher and Puma::Single class so we can tell
# if the server has been started.
module Puma
  class Launcher
    def running
      @runner and @runner.running
    end
  end

  class Runner
  end

  class Single < Runner
    def running
      @server and @server.running
    end
  end
end

module OpenC3
  # JsonDRb implements the JSON-RPC 2.0 Specification to provide an interface
  # for both internal and external tools to access the OpenC3 server. It
  # provides methods to install an access control list to control access to the
  # API. It also limits the available methods to a known list of allowable API
  # methods.
  class JsonDRb
    # Minimum amount of time in seconds to receive the JSON request,
    # process it, and send the response. Requests for less than this amount
    # will be set to the minimum
    MINIMUM_REQUEST_TIME = 0.0001
    STOP_SERVICE_TIMEOUT = 10.0 # seconds to wait when stopping the service
    PUMA_THREAD_TIMEOUT  = 10.0 # seconds to wait for the puma threads to die
    SERVER_START_TIMEOUT = 15.0 # seconds to wait for the server to start

    @@debug = false

    # @return [Integer] The number of JSON-RPC requests processed
    attr_accessor :request_count
    # @return [Array<String>] List of methods that should be allowed
    attr_accessor :method_whitelist
    # @return [ACL] The access control list
    # attr_accessor :acl

    attr_accessor :object

    def initialize
      @thread = nil
      # @acl = nil
      @object = nil
      @method_whitelist = nil
      @request_count = 0
      @request_times = []
      @request_times_index = 0
      @request_mutex = Mutex.new
      @server = nil
      @server_mutex = Mutex.new
    end

    # Returns the number of connected clients
    # @return [Integer] The number of connected clients
    def num_clients
      clients = 0
      @server_mutex.synchronize do
        if @server
          # @server.stats() returns a string like: { "backlog": 0, "running": 0 }
          # "running" indicates the number of server threads running, and
          # therefore the number of clients connected.
          stats = @server.stats()
          stats =~ /"running": \d*/
          clients = $&.split(":")[1].to_i
        end
      end
      return clients
    end

    # Stops the DRb service by closing the socket and the processing thread
    def stop_service
      # Kill the server thread
      # parameters are owner, thread, graceful_timeout, timeout_interval, hard_timeout
      OpenC3.kill_thread(self, @thread, STOP_SERVICE_TIMEOUT, 0.1, STOP_SERVICE_TIMEOUT)
      @thread = nil
      @server_mutex.synchronize do
        @server = nil
      end
    end

    # Gracefully kill the thread
    def graceful_kill
      @server_mutex.synchronize do
        @server.stop if @server and @server.running
      rescue
      end
    end

    # @param hostname [String] The host to start the service on
    # @param port [Integer] The port number to listen for connections
    # @param object [Object] The object to send the DRb requests to.
    def start_service(hostname = nil, port = nil, object = nil, max_threads = 1000)
      server_started = false
      @server_mutex.synchronize do
        server_started = true if @server
      end
      return if server_started

      if hostname and port and object
        @object = object
        hostname = '127.0.0.1'.freeze if hostname.to_s.upcase == 'LOCALHOST'.freeze

        @thread = Thread.new do
          # Create an http server to accept requests from clients

          server_config = {
            :Host => hostname,
            :Port => port,
            :Silent => true,
            :Verbose => false,
            :Threads => "0:#{max_threads}",
          }

          # The run call will block until the server is stopped.
          Rack::Handler::Puma.run(JsonDrbRack.new(self), server_config) do |server|
            @server_mutex.synchronize do
              @server = server
            end
          end

          # Wait for all puma threads to stop before trying to close
          # the sockets
          start_time = Time.now
          while true
            puma_threads = false
            Thread.list.each { |thread| puma_threads = true if thread.inspect.match?(/puma/) }
            break if !puma_threads
            break if (Time.now - start_time) > PUMA_THREAD_TIMEOUT

            sleep 0.25
          end

          # Puma doesn't clean up it's own sockets after shutting down,
          # so we'll do that here.
          @server_mutex.synchronize do
            @server.binder.close() if @server
          end

        # The address in use error is pretty typical if an existing
        # server is running so explicitly rescue this
        rescue Errno::EADDRINUSE
          @server = nil
          raise "Error binding to port #{port}.\n" +
                "Either another application is using this port\n" +
                "or the operating system is being slow cleaning up.\n" +
                "Make sure all sockets/streams are closed in all applications,\n" +
                "wait 1 minute and try again."
        # Something else went wrong which is fatal
        rescue => error
          @server = nil
          Logger.error "JsonDRb http server could not be started or unexpectedly died.\n#{error.formatted}"
          OpenC3.handle_fatal_exception(error)
        end

        # Wait for the server to be started in the thread before returning.
        start_time = Time.now
        while ((Time.now - start_time) < SERVER_START_TIMEOUT) and !server_started
          sleep(0.1)
          @server_mutex.synchronize do
            server_started = true if @server and @server.running
          end
        end
        raise "JsonDRb http server could not be started." unless server_started

      elsif hostname or port or object
        raise "0 or 3 parameters must be given"
      else
        # Client - Noop
      end
    end

    # @return [Thread] The server thread listening for incoming requests
    attr_reader :thread

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

    # @return [Boolean] Whether debug messages are enabled
    def self.debug?
      @@debug
    end

    # @param value [Boolean] Whether to enable debug messages
    def self.debug=(value)
      @@debug = value
    end

    # Process the JSON request data, execute the method, and create a response.
    #
    # @param request_data [String] The JSON encoded request
    # @param request_headers [Hash] The requests headers sent with the request
    # @param start_time [Time] The time when the initial request was received
    # @return response_data, error_code [String, Integer/nil] The JSON encoded
    #   response and error code
    def process_request(request_data:, request_headers:, start_time:)
      @request_count += 1
      begin
        request = JsonRpcRequest.from_json(request_data, request_headers)
        response = nil
        error_code = nil
        response_data = nil

        if (@method_whitelist and @method_whitelist.include?(request.method.downcase())) or
           (!@method_whitelist and !JsonRpcRequest::DANGEROUS_METHODS.include?(request.method.downcase()))
          begin
            if request.keyword_params
              result = @object.public_send(request.method.downcase().intern, *request.params, **request.keyword_params)
            else
              result = @object.public_send(request.method.downcase().intern, *request.params)
            end
            if request.id
              response = JsonRpcSuccessResponse.new(result, request.id)
            end
          rescue Exception => error
            # Filter out the framework stack trace (rails, rack, puma etc)
            lines = error.formatted.split("\n")
            i = lines.find_index { |row| row.include?('actionpack') || row.include?('activesupport') }
            Logger.error lines[0...i].join("\n")

            if request.id
              if NoMethodError === error
                error_code = JsonRpcError::ErrorCode::METHOD_NOT_FOUND
                response = JsonRpcErrorResponse.new(
                  JsonRpcError.new(error_code, "Method not found", error), request.id
                )
              elsif ArgumentError === error
                error_code = JsonRpcError::ErrorCode::INVALID_PARAMS
                response = JsonRpcErrorResponse.new(
                  JsonRpcError.new(error_code, "Invalid params", error), request.id
                )
              elsif AuthError === error
                error_code = JsonRpcError::ErrorCode::AUTH_ERROR
                response = JsonRpcErrorResponse.new(
                  JsonRpcError.new(error_code, error.message, error), request.id
                )
              elsif ForbiddenError === error
                error_code = JsonRpcError::ErrorCode::FORBIDDEN_ERROR
                response = JsonRpcErrorResponse.new(
                  JsonRpcError.new(error_code, error.message, error), request.id
                )
              else
                error_code = JsonRpcError::ErrorCode::OTHER_ERROR
                response = JsonRpcErrorResponse.new(
                  JsonRpcError.new(error_code, error.message, error), request.id
                )
              end
            end
          end
        else
          if request.id
            error_code = JsonRpcError::ErrorCode::OTHER_ERROR
            response = JsonRpcErrorResponse.new(
              JsonRpcError.new(error_code, "Cannot call unauthorized methods"), request.id
            )
          end
        end
        response_data = process_response(response, start_time) if response
        return response_data, error_code
      rescue => error
        error_code = JsonRpcError::ErrorCode::INVALID_REQUEST
        response = JsonRpcErrorResponse.new(JsonRpcError.new(error_code, "Invalid Request", error), nil)
        response_data = process_response(response, start_time)
        return response_data, error_code
      end
    end

    protected

    def process_response(response, start_time)
      response_data = response.to_json(:allow_nan => true)
      STDOUT.puts response_data if JsonDRb.debug?
      end_time = Time.now.sys
      request_time = end_time - start_time
      add_request_time(request_time)
      return response_data
    end
  end
end
