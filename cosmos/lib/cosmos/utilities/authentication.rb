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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder


module Cosmos

  # Basic exception for known errors
  class CosmosAuthenticationError < StandardError; end

  class CosmosAuthenticationRetryableError < CosmosAuthenticationError; end

  # Cosmos base / open source authentication code
  class CosmosAuthentication

    #
    def initialize()
      @token = ENV['COSMOS_API_PASSWORD'] || ENV['COSMOS_SERVICE_PASSWORD']
      if @token.nil?
        raise CosmosAuthenticationError, "Authentication requires environment variables COSMOS_API_PASSWORD or COSMOS_SERVICE_PASSWORD"
      end
    end

    # Load the token from the environment
    def token()
      @token
    end

  end

  # Cosmos enterprise Keycloak authentication code
  class CosmosKeycloakAuthentication < CosmosAuthentication
    # {
    #     "access_token": "",
    #     "expires_in": 600,
    #     "refresh_expires_in": 1800,
    #     "refresh_token": "",
    #     "token_type": "bearer",
    #     "id_token": "",
    #     "not-before-policy": 0,
    #     "session_state": "",
    #     "scope": "openid email profile"
    # }

    # @param url [String] The url of the cosmos or keycloak in the cluster
    def initialize(url)
      @url = url
      @auth_mutex = Mutex.new
      @refresh_token = nil
      @expires_at = nil
      @refresh_expires_at = nil
      @token = nil
      @log = [nil, nil]
    end

    # Load the token from the environment
    def token()
      @auth_mutex.synchronize do
        @log = [nil, nil]
        current_time = Time.now.to_i
        if @token.nil?
          _make_token(current_time)
        elsif @refresh_expires_at < current_time
          _make_token(current_time)
        elsif @expires_at < current_time
          _refresh_token(current_time)
        end
      end
      "Bearer #{@token}"
    end

    private

    # Make the token and save token to instance
    def _make_token(current_time)
      client_id = ENV['COSMOS_API_CLIENT'] || 'api'
      data = "username=#{ENV['COSMOS_API_USER']}&password=#{ENV['COSMOS_API_PASSWORD']}"
      data << "&client_id=#{client_id}"
      data << '&grant_type=password&scope=openid'
      headers = {
        'Content-Type' => 'application/x-www-form-urlencoded',
        'User-Agent' => 'CosmosKeycloakAuthorization / 5.0.0 (ruby/cosmos/lib/utilities/authentication)',
      }
      oath = _make_request(headers, data)
      @token = oath['access_token']
      @refresh_token = oath['refresh_token']
      @expires_at = current_time + oath['expires_in']
      @refresh_expires_at = current_time + oath['refresh_expires_in']
    end

    # Refresh the token and save token to instance
    def _refresh_token(current_time)
      client_id = ENV['COSMOS_API_CLIENT'] || 'api'
      data = "client_id=#{client_id}&refresh_token=#{@refresh_token}&grant_type=refresh_token"
      headers = {
        'Content-Type' => 'application/x-www-form-urlencoded',
        'User-Agent' => 'CosmosKeycloakAuthorization / 5.0.0 (ruby/cosmos/lib/utilities/authentication)',
      }
      oath = _make_request(headers, data)
      @token = oath["access_token"]
      @refresh_token = oath["refresh_token"]
      @expires_at = current_time + oath["expires_in"]
      @refresh_expires_at = current_time + oath["refresh_expires_in"]
    end

    # Make the post request to keycloak
    def _make_request(headers, data)
      uri = URI("#{@url}/auth/realms/COSMOS/protocol/openid-connect/token")
      @log[0] = "request uri: #{uri.to_s} header: #{headers.to_s} body: #{data.to_s}"
      STDOUT.puts @log[0] if JsonDRb.debug?
      saved_verbose = $VERBOSE; $VERBOSE = nil
      begin
        resp = HTTPClient.new().post(uri, :body => data, :header => headers)
      ensure
        $VERBOSE = saved_verbose
      end
      @log[1] = "response status: #{resp.status} header: #{resp.headers} body: #{resp.body}"
      STDOUT.puts @log[1] if JsonDRb.debug?
      if resp.status >= 200 && resp.status <= 299
        return JSON.parse(resp.body)
      elsif resp.status >= 500 && resp.status <= 599
        raise CosmosAuthenticationRetryableError, "authentication request retryable #{@log[0]} ::: #{@log[1]}"
      else
        raise CosmosAuthenticationError, "authentication request failed #{@log[0]} ::: #{@log[1]}"
      end
    end

  end

end