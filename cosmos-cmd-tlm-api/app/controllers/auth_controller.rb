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

require 'cosmos'
require 'cosmos/models/auth_model'

# This controller only exists in base since Keycloak handles auth in EE
begin
  require 'enterprise-cosmos/controllers/auth_controller'
rescue LoadError
  class AuthController < ApplicationController
    def token_exists
      result = Cosmos::AuthModel.is_set?
      render :json => {
        result: result
      }
    end

    def verify
      result = Cosmos::AuthModel.verify(params[:token])
      render :json => {
        result: result
      }
    end

    def set
      result = Cosmos::AuthModel.set(params[:token], params[:old_token])
      Cosmos::Logger.info("Password changed", user: user_info(request.headers['HTTP_AUTHORIZATION']))
      render :json => {
        result: result
      }
    end
  end
end
