# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'rack'

module Cosmos

  # JsonDrbRack implements a rack application that can be served by a
  # webserver to process COSMOS json_drb requests via http.
  class JsonDrbRack
    # @param drb [JsonDRb] - An instance of the JsonDRb class that'll be used
    #   to process the JSON request and generate a response
    def initialize(drb)
      @drb = drb
    end

    # Handles a request.
    #
    # @param env [Hash] - A rack env hash, can be turned into a Rack::Request
    # @return [Integer, Hash, [String]] - Http response code, content headers,
    #   response body
    def call(env)
      request = Rack::Request.new(env)

      # ACL allow_addr? function takes address in the form returned by
      # IPSocket.peeraddr.
      # req_addr = ["AF_INET", request.port, request.host.to_s, request.ip.to_s]

      # if @drb.acl and !@drb.acl.allow_addr?(req_addr)
      #  status       = 403
      #  content_type = "text/plain"
      #  body         = "Forbidden"
      if request.post?
        status, content_type, body = handle_post(request)
      else
        status       = 405
        content_type = "text/plain"
        body         = "Request not allowed"
      end

      return status, { 'Content-Type' => content_type }, [body]
    end

    # Handles an http post.
    #
    # @param request [Rack::Request] - A rack post request
    # @return [Integer, String, String] - Http response code, content type,
    #   response body.
    def handle_post(request)
      request_data = request.body.read
      start_time = Time.now.sys
      response_data, error_code = @drb.process_request(request_data, start_time)

      # Convert json error code into html status code
      # see http://www.jsonrpc.org/historical/json-rpc-over-http.html#errors
      if error_code
        case error_code
        when JsonRpcError::ErrorCode::PARSE_ERROR      then status = 500 # Internal server error
        when JsonRpcError::ErrorCode::INVALID_REQUEST  then status = 400 # Bad request
        when JsonRpcError::ErrorCode::METHOD_NOT_FOUND then status = 404 # Not found
        when JsonRpcError::ErrorCode::INVALID_PARAMS   then status = 500 # Internal server error
        when JsonRpcError::ErrorCode::INTERNAL_ERROR   then status = 500 # Internal server error
        else status = 500 # Internal server error
        end
      else
        status = 200 # OK
      end

      return status, "application/json-rpc", response_data
    end
  end
end
