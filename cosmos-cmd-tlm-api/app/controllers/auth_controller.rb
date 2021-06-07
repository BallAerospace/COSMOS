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
      render :json => {
        result: result
      }
    end

    # This is used by the ScopeSelector component on the front end. It's here to
    # simplify code elsewhere. ScopesController isn't getting overridden in EE,
    # but this already is. All users have access to all roles in base, but they're
    # restricted to the user's roles in EE
    def scopes
      # Can't use the authorize function (like in ScopesController) because it requires a scope
      # param, but the client doesn't know what the scopes are yet. Just check the password.
      raise "Invalid password" unless Cosmos::AuthModel.verify(params[:token])

      result = Cosmos::ScopeModel.names
      render :json => {
        result: result
      }
    end

  end

end
