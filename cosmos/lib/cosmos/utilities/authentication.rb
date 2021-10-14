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

  # Cosmos base / open source authentication code
  class CosmosAuthentication

    #
    def initialize()
      @token = ENV['COSMOS_API_PASSWORD'] || ENV['COSMOS_SERVICE_PASSWORD']
      if @token.nil?
        raise DRb::DRbConnError, "Authentication requires environment variables COSMOS_API_PASSWORD or COSMOS_SERVICE_PASSWORD"
      end
    end

    # Load the token from the environment
    def token()
      @token
    end

  end

  # Cosmos enterprise Keycloak authentication code
  class CosmosKeycloakAuthentication < CosmosAuthentication

    # @param url [String] The url of the cosmos-keycloak-api
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

    def _make_token(current_time)
      oath = _make_token_request()
      raise DRb::DRbConnError, "make failed authentication: #{@log[0]} ::: #{@log[1]}" unless oath
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
      data = "username=#{ENV['COSMOS_API_USER']}"
      data << "&password=#{ENV['COSMOS_API_PASSWORD']}"
      data << "&client_id=#{ENV['COSMOS_API_CLIENT']}"
      data << "&client_secret=#{ENV['COSMOS_API_SECRET']}"
      data << '&grant_type=password'
      data << '&scope=openid'
      headers = {
        'Content-Type' => 'application/x-www-form-urlencoded',
        'User-Agent' => 'CosmosKeycloakAuthorization / 5.0.0 (ruby/cosmos/lib/utilities/authentication)',
      }
      uri = URI("#{@url}/auth/realms/COSMOS/protocol/openid-connect/token")
      @log[0] = "Make Request: #{uri.to_s} #{headers.to_s} #{data.to_s}"
      STDOUT.puts @log[0] if JsonDRb.debug?
      resp = HTTPClient.new().post(uri, :body => data, :header => headers)
      log[1] = "Make Response: #{resp.status} #{resp.headers} #{resp.body}"
      STDOUT.puts @log[1] if JsonDRb.debug?
      JSON.parse(resp.body) if String === resp.body
    end

    def _refresh_token(current_time)
      oath = _make_refresh_request()
      raise DRb::DRbConnError, "refresh failed authentication: #{@log[0]} ::: #{@log[1]}" unless oath
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
      data = "client_id=#{ENV['COSMOS_API_CLIENT']}"
      data << "&refresh_token=#{@refresh_token}"
      data << "&grant_type=refresh_token"
      headers = {
        'Content-Type' => 'application/x-www-form-urlencoded',
        'User-Agent' => 'CosmosKeycloakAuthorization / 5.0.0 (ruby/cosmos/lib/utilities/authentication)',
      }
      uri = URI("#{@url}/auth/realms/COSMOS/protocol/openid-connect/token")
      @log[0] = "Refresh Request: #{uri.to_s} #{headers.to_s} #{data.to_s}"
      STDOUT.puts @log[0] if JsonDRb.debug?
      resp = HTTPClient.new().post(uri, :body => data, :header => headers)
      log[1] = "Refresh Response: #{resp.status} #{resp.headers} #{resp.body}"
      STDOUT.puts @log[1] if JsonDRb.debug?
      JSON.parse(resp.body) if String === resp.body
    end

  end

end