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

require 'openc3'
require 'openc3/utilities/authentication'
require 'openc3/io/json_drb'

require 'thread'
require 'socket'
require 'json'
# require 'drb/acl'
require 'drb/drb'
require 'uri'
require 'httpclient'


module OpenC3

  class JsonApiError < StandardError; end

  # Used to forward all method calls to the remote server object. Before using
  # this class ensure the remote service has been started in the server class:
  #
  #   json = JsonDrb.new
  #   json.start_service('127.0.0.1', 7777, self)
  #
  # Now the JsonApiObject can be used to call server methods directly:
  #
  #   server = JsonApiObject('http://openc3-cmd-tlm-api:2901', 1.0)
  #   server.cmd(*args)
  #
  class JsonApiObject 
    attr_reader :request_data
    attr_reader :response_data

    USER_AGENT = 'OpenC3 / v5 (ruby/openc3/lib/io/json_api_object)'.freeze

    # @param url [String] The url of openc3-cmd-tlm-api http://openc3-cmd-tlm-api:2901
    # @param timeout [Float] The time to wait before disconnecting 1.0
    # @param authentication [OpenC3Authentication] The authentication object if nill initialize will generate
    def initialize(url: ENV['OPENC3_API_URL'], timeout: 1.0, authentication: nil)
      @http = nil
      @mutex = Mutex.new
      @request_data = ""
      @response_data = ""
      @url = url
      @log = [nil, nil, nil]
      @authentication = authentication.nil? ? OpenC3Authentication.new() : authentication
      @timeout = timeout
      @shutdown = false
    end

    # Forwards all method calls to the remote service.
    #
    # @param method_params [Array] Array of parameters to pass to the method
    # @param keyword_params [Hash<Symbol, Variable>] Hash of keyword parameters
    # @return The result of the method call. 
    def request(*method_params, **keyword_params)
      raise JsonApiError, "Shutdown" if @shutdown
      method = method_params[0]
      endpoint = method_params[1]
      @mutex.synchronize do
        kwargs = _generate_kwargs(keyword_params)
        for attempt in 1..3
          @log = [nil, nil, nil]
          connect() if !@http
          response = _send_request(method: method, endpoint: endpoint, kwargs: kwargs)
          return response unless response.code >= 500
          sleep attempt
        end
        return nil
      end
    end

    # Disconnects from http server
    def disconnect
      @http.reset_all() if @http
      @http = nil
    end

    # Permanently disconnects from the http server
    def shutdown
      @shutdown = true
      disconnect()
    end

    private

    def connect
      begin
        @http = HTTPClient.new
        @http.connect_timeout = @timeout
        @http.receive_timeout = nil # Allow long polling
      rescue => e
        raise JsonApiError, e.message
      end
    end

    # NOTE: This is a helper method and should not be called directly
    def _generate_kwargs(keyword_params)
      kwargs = {}
      keyword_params.each do |key, value|
        kwargs[key.intern] = value
      end
      kwargs[:scope] = _generate_scope(kwargs)
      kwargs[:headers] = _generate_headers(kwargs)
      kwargs[:data] = _generate_data(kwargs)
      kwargs[:query] = _generate_query(kwargs)
      return kwargs
    end

    # NOTE: This is a helper method and should not be called directly
    def _generate_scope(kwargs)
      scope = kwargs[:scope]
      if scope.nil?
        raise JsonApiError, "no scope keyword found: #{kwargs}"
      elsif scope.is_a?(String) == false
        raise JsonApiError, "incorrect type for keyword 'scope' MUST be String: #{scope}"
      end
      return scope
    end

    # NOTE: This is a helper method and should not be called directly
    def _generate_headers(kwargs)
      headers = kwargs[:headers]
      if headers.nil?
        headers = kwargs[:headers] = {}
      elsif headers.is_a?(Hash) == false
        raise JsonApiError, "incorrect type for keyword 'headers' MUST be Hash: #{headers}"
      end
      
      headers['Content-Type'] = 'application/json' if kwargs[:json]
      return headers.update({
        'User-Agent' => USER_AGENT,
        'Authorization' => @authentication.token(),
      })
    end

    # NOTE: This is a helper method and should not be called directly
    def _generate_data(kwargs)
      data = kwargs[:data]
      if data.nil?
        data = kwargs[:data] = {}
      elsif data.is_a?(Hash) == false
        raise JsonApiError, "incorrect type for keyword 'data' MUST be Hash: #{data}"
      end
      return kwargs[:json] ? JSON.generate(kwargs[:data]) : kwargs[:data]
    end

    # NOTE: This is a helper method and should not be called directly
    def _generate_query(kwargs)
      query = kwargs[:query]
      if query.nil?
        query = kwargs[:query] = {}
      elsif query.is_a?(Hash) == false
        raise JsonApiError, "incorrect type for keyword 'query' MUST be Hash: #{query}"
      end
      kwargs[:query].update(:scope => kwargs[:scope]) if kwargs[:scope]
    end

    # NOTE: This is a helper method and should not be called directly
    def _send_request(method:, endpoint:, kwargs:)
      begin
        uri = URI("#{@url}#{endpoint}")
        @log[0] = "#{method} Request: #{uri.to_s} #{kwargs}"
        STDOUT.puts @log[0] if JsonDRb.debug?
        resp = _http_request(method: method, uri: uri, kwargs: kwargs)
        @log[1] = "#{method} Response: #{resp.status} #{resp.headers} #{resp.body}"
        STDOUT.puts @log[1] if JsonDRb.debug?
        @response_data = resp.body
        return resp
      rescue StandardError => e
        @log[2] = "#{method} Exception: #{e.class}, #{e.message}, #{e.backtrace}"
      end
    end

    # NOTE: This is a helper method and should not be called directly
    def _http_request(method:, uri:, kwargs:)
      case method
      when 'get', :get
        return @http.get(uri, :header => kwargs[:headers], :query => kwargs[:query])
      when 'post', :post
        return @http.post(uri, :header => kwargs[:headers], :query => kwargs[:query], :body => kwargs[:data])
      when 'put', :put
        return @http.put(uri, :header => kwargs[:headers], :query => kwargs[:query], :body => kwargs[:data])
      when 'delete', :delete
        return @http.delete(uri, :header => kwargs[:headers], :query => kwargs[:query])
      else
        raise JsonApiError, "no method found: '#{method}'"
      end
    end

  end # class JsonApiObject
end
