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
    begin
      authorize(permission: 'system', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { 'status' => 'error', 'message' => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { 'status' => 'error', 'message' => e.message }, :status => 403) and return
    end
    render :json => Screen.all(params[:scope].upcase, params[:target].upcase)
  end

  def screen
    begin
      authorize(permission: 'system', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { 'status' => 'error', 'message' => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { 'status' => 'error', 'message' => e.message }, :status => 403) and return
    end
    screen = Screen.find(params[:scope].upcase, params[:target].upcase, params[:screen].downcase)
    if screen
      render :json => screen
    else
      head :not_found
    end
  end

  def screen_save
    begin
      authorize(permission: 'system', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { 'status' => 'error', 'message' => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { 'status' => 'error', 'message' => e.message }, :status => 403) and return
    end
    screen = Screen.create(params[:scope].upcase, params[:target].upcase, params[:screen].downcase, params[:text])
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
    STDOUT.puts "API request data:\n #{request_data.inspect}"
    response_data, error_code = Cosmos::Cts.instance.json_drb.process_request(
      request_data: request_data,
      request_headers: request_headers,
      start_time: Time.now.sys)

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
