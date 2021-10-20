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


module Cosmos

  # Basic exception for known errors
  class CosmosAuthenticationError < StandardError; end

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

    # @param url [String] The url of the cosmos or keycloak in the cluster
    # @param user [String] The user that is being authenticated
    # @param password [String] The password that is being used
    # @param client [String] The keycloak client that us being used
    # @param secret [String] The secret that is being used
    def initialize(url, user = nil, password = nil, client = nil, secret = nil)
      @url = url
      @user = user || ENV['COSMOS_API_USER']
      @password = password || ENV['COSMOS_API_PASSWORD']
      @client = client || ENV['COSMOS_API_CLIENT']
      @secret = secret || ENV['COSMOS_API_SECRET']
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
      oath = _make_token_request()
      @token = oath['access_token']
      @refresh_token = oath['refresh_token']
      @expires_at = current_time + oath['expires_in']
      @refresh_expires_at = current_time + oath['refresh_expires_in']
    end

    def _make_token_request()
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
      data = "username=#{@user}&password=#{@password}"
      data << "&client_id=#{@client}&client_secret=#{@secret}"
      data << '&grant_type=password&scope=openid'
      headers = {
        'Content-Type' => 'application/x-www-form-urlencoded',
        'User-Agent' => 'CosmosKeycloakAuthorization / 5.0.0 (ruby/cosmos/lib/utilities/authentication)',
      }
      return _make_request(headers, data)
    end

    # Refresh the token and save token to instance
    def _refresh_token(current_time)
      oath = _make_refresh_request()
      @token = oath["access_token"]
      @refresh_token = oath["refresh_token"]
      @expires_at = current_time + oath["expires_in"]
      @refresh_expires_at = current_time + oath["refresh_expires_in"]
    end

    def _make_refresh_request()
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
      data = "client_id=#{@cleint}&refresh_token=#{@refresh_token}&grant_type=refresh_token"
      headers = {
        'Content-Type' => 'application/x-www-form-urlencoded',
        'User-Agent' => 'CosmosKeycloakAuthorization / 5.0.0 (ruby/cosmos/lib/utilities/authentication)',
      }
      return _make_request(headers, data)
    end

    # Make the post request to keycloak
    def _make_request(headers, data)
      uri = URI("#{@url}/auth/realms/COSMOS/protocol/openid-connect/token")
      @log[0] = "make request uri: #{uri.to_s} header: #{headers.to_s} body: #{data.to_s}"
      STDOUT.puts @log[0] if JsonDRb.debug?
      resp = HTTPClient.new().post(uri, :body => data, :header => headers)
      @log[1] = "make response status: #{resp.status} header: #{resp.headers} body: #{resp.body}"
      STDOUT.puts @log[1] if JsonDRb.debug?
      if resp.status >= 200 && resp.status <= 299
        return JSON.parse(resp.body)
      else
        raise CosmosAuthenticationError, "authentication request failed #{@log[0]} ::: #{@log[1]}"
      end
    end

  end

end