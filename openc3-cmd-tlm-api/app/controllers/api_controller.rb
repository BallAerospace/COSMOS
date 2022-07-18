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

class ApiController < ApplicationController
  def screens
    return unless authorization('system')
    render :json => Screen.all(params[:scope].upcase, params[:target].upcase)
  end

  def screen
    return unless authorization('system')
    screen = Screen.find(params[:scope].upcase, params[:target].upcase, params[:screen].downcase)
    if screen
      render :json => screen
    else
      head :not_found
    end
  end

  def screen_save
    return unless authorization('system')
    screen = Screen.create(params[:scope].upcase, params[:target].upcase, params[:screen].downcase, params[:text])
    OpenC3::Logger.info("Screen saved: #{params[:target]} #{params[:screen]}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
    if screen
      render :json => screen
    else
      head :not_found
    end
  end

  def api
    req = Rack::Request.new(request.env)

    if request.post?
      request_headers = Hash[*request.env.select {|k,v| k.start_with? 'HTTP_'}.sort.flatten]
      request_data = req.body.read
      status, content_type, body = handle_post(request_data, request_headers)
      OpenC3::Logger.info("API data: #{request_data}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      OpenC3::Logger.debug("API headers: #{request_headers}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
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
  # @param request_data [String] - A String of the post body from the request
  # @param request_headers [Hash] - A Hash of the headers from the post request
  # @return [Integer, String, String] - Http response code, content type,
  #   response body.
  def handle_post(request_data, request_headers)
    response_data, error_code = OpenC3::Cts.instance.json_drb.process_request(
      request_data: request_data,
      request_headers: request_headers,
      start_time: Time.now.sys)

    # Convert json error code into html status code
    # see http://www.jsonrpc.org/historical/json-rpc-over-http.html#errors
    if error_code
      case error_code
      when OpenC3::JsonRpcError::ErrorCode::PARSE_ERROR      then status = 500 # Internal server error
      when OpenC3::JsonRpcError::ErrorCode::INVALID_REQUEST  then status = 400 # Bad request
      when OpenC3::JsonRpcError::ErrorCode::METHOD_NOT_FOUND then status = 404 # Not found
      when OpenC3::JsonRpcError::ErrorCode::INVALID_PARAMS   then status = 500 # Internal server error
      when OpenC3::JsonRpcError::ErrorCode::INTERNAL_ERROR   then status = 500 # Internal server error
      when OpenC3::JsonRpcError::ErrorCode::AUTH_ERROR       then status = 401
      when OpenC3::JsonRpcError::ErrorCode::FORBIDDEN_ERROR  then status = 403
      else status = 500 # Internal server error
      end
      # Note we don't log an error here because it's logged in JsonDRb::process_request
    else
      status = 200 # OK
    end
    return status, "application/json-rpc", response_data
  end
end
