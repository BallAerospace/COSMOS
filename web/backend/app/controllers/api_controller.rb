#require 'json_rpc_bridge'

class ApiController < ApplicationController
  def apicmd
    mutex = Thread.current[:http_mutex]
    unless mutex
      mutex = Mutex.new
      Thread.current[:http_mutex] = mutex
    end
    response_data = nil

    mutex.synchronize do
      http = Thread.current[:http]
      if !http or Thread.current[:request_in_progress]
        http.reset_all if http
        http = HTTPClient.new
        http.connect_timeout = 5
        http.receive_timeout = 5
        Thread.current[:http] = http
      end

      request_data = request.raw_post
      Thread.current[:request_in_progress] = true
      headers = {'Content-Type' => 'application/json-rpc'}
      uri = URI("http://127.0.0.1:7777")
      response = http.post(uri, :body => request_data, :header => headers)
      response_data = response.body
      Thread.current[:request_in_progress] = false
    end
    render :plain => response_data
  end
end
