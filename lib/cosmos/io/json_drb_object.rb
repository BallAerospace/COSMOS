# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
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
require 'uri'
require 'httpclient'

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
    attr_reader :request_data
    attr_reader :response_data

    # @param hostname [String] The name of the machine which has started
    #   the JSON service
    # @param port [Integer] The port number of the JSON service
    def initialize(hostname, port, connect_timeout = 1.0)
      hostname = '127.0.0.1' if (hostname.to_s.upcase == 'LOCALHOST')
      begin
        Socket.pack_sockaddr_in(port, hostname)
      rescue => error
        if error.message =~ /getaddrinfo/
          raise "Invalid hostname: #{hostname}"
        else
          raise error
        end
      end
      @request_data = ""
      @response_data = ""
      @hostname = hostname
      @port = port
      @uri = URI("http://#{@hostname}:#{@port}/api")
      @http = nil
      @mutex = Mutex.new
      @id = 0
      @request_in_progress = false
      @connect_timeout = connect_timeout
      @connect_timeout = @connect_timeout.to_f if @connect_timeout
      @shutdown = false
    end

    # Disconnects from http server
    def disconnect
      @http.reset_all if @http
    end

    # Permanently disconnects from the http server
    def shutdown
      @shutdown = true
      disconnect()
    end

    # Forwards all method calls to the remote service.
    #
    # @param method_name [Symbol] Name of the method to call
    # @param method_params [Array] Array of parameters to pass to the method
    # @param keyword_params [Hash<Symbol, Variable>] Hash of keyword parameters
    # @return The result of the method call. If the method raises an exception
    #   the same exception is also raised. If something goes wrong with the
    #   protocol a DRb::DRbConnError exception is raised.
    def method_missing(method_name, *method_params, **keyword_params)
      @mutex.synchronize do
        first_try = true
        loop do
          raise DRb::DRbConnError, "Shutdown" if @shutdown
          connect() if !@http or @request_in_progress

          response = make_request(method_name, method_params, keyword_params, first_try)
          unless response
            disconnect()
            was_first_try = first_try
            first_try = false
            next if was_first_try
          end
          return handle_response(response)
        end
      end
    end

    private

    def connect
      if @request_in_progress
        disconnect()
        @request_in_progress = false
      end
      begin
        if !@http
          @http = HTTPClient.new
          @http.connect_timeout = @connect_timeout
          @http.receive_timeout = nil # Allow long polling
        end
      rescue => e
        raise DRb::DRbConnError, e.message
      end
    end

    def make_request(method_name, method_params, keyword_params, first_try)
      request = JsonRpcRequest.new(method_name, method_params, keyword_params, @id)
      @id += 1

      @request_data = request.to_json(:allow_nan => true)
      begin
        STDOUT.puts "\nRequest:\n" if JsonDRb.debug?
        STDOUT.puts @request_data if JsonDRb.debug?
        @request_in_progress = true
        headers = {'Content-Type' => 'application/json-rpc'}
        res = @http.post(@uri,
                         :body   => @request_data,
                         :header => headers)
        @response_data = res.body
        @request_in_progress = false
        STDOUT.puts "Response:\n" if JsonDRb.debug?
        STDOUT.puts @response_data if JsonDRb.debug?
      rescue => e
        disconnect()
        return false if first_try
        raise DRb::DRbConnError, e.message, e.backtrace
      end
      @response_data
    end

    def handle_response(response_data)
      # The code below will always either raise or return breaking out of the loop
      if response_data and response_data.to_s.length > 0
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
        disconnect()
        raise DRb::DRbConnError, "No response from server"
      end
    end

  end # class JsonDRbObject

end # module Cosmos
