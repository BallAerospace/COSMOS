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

class ApiController < ApplicationController
  def screens
    render :json => Screen.all(params[:scope].upcase, params[:target].upcase)
  end

  def screen
    screen = Screen.find(params[:scope].upcase, params[:target].upcase, params[:screen].downcase)
    if screen
      render :json => screen
    else
      head :not_found
    end
  end

  def api
    req = Rack::Request.new(request.env)

    # ACL allow_addr? function takes address in the form returned by
    # IPSocket.peeraddr.
    req_addr = ["AF_INET", req.port, req.host.to_s, req.ip.to_s]

    # if Cosmos::CmdTlmServer.instance.json_drb.acl and !Cosmos::CmdTlmServer.instance.json_drb.acl.allow_addr?(req_addr)
    #  status       = 403
    #  content_type = "text/plain"
    #  body         = "Forbidden"
    if request.post?
      status, content_type, body = handle_post(req)
    else
      status       = 405
      content_type = "text/plain"
      body         = "Request not allowed"
    end

    rack_response = Rack::Response.new([body], status, { 'Content-Type' => content_type })
    self.response = ActionDispatch::Response.new(*rack_response.to_a)
    self.response.close
  end

  # Handles an http post.
  #
  # @param request [Rack::Request] - A rack post request
  # @return [Integer, String, String] - Http response code, content type,
  #   response body.
  def handle_post(request)
    request_data = request.body.read
    start_time = Time.now.sys
    response_data, error_code = Cosmos::Cts.instance.json_drb.process_request(request_data, start_time)

    # Convert json error code into html status code
    # see http://www.jsonrpc.org/historical/json-rpc-over-http.html#errors
    if error_code
      case error_code
      when Cosmos::JsonRpcError::ErrorCode::PARSE_ERROR      then status = 500 # Internal server error
      when Cosmos::JsonRpcError::ErrorCode::INVALID_REQUEST  then status = 400 # Bad request
      when Cosmos::JsonRpcError::ErrorCode::METHOD_NOT_FOUND then status = 404 # Not found
      when Cosmos::JsonRpcError::ErrorCode::INVALID_PARAMS   then status = 500 # Internal server error
      when Cosmos::JsonRpcError::ErrorCode::INTERNAL_ERROR   then status = 500 # Internal server error
      when Cosmos::JsonRpcError::ErrorCode::AUTH_ERROR       then status = 401
      when Cosmos::JsonRpcError::ErrorCode::FORBIDDEN_ERROR  then status = 403
      else status = 500 # Internal server error
      end
      parsed = JSON.parse(response_data)
      if parsed["error"]
        Rails.logger.error "\n#{parsed['error']['data']['class']} : #{parsed['error']['data']['message']}\n"
        Rails.logger.error parsed['error']['data']['backtrace'].join("\n")
      end
    else
      status = 200 # OK
    end

    return status, "application/json-rpc", response_data
  end
end
