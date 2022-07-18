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

require 'openc3'
require 'openc3/models/auth_model'

# This controller only exists in base since Keycloak handles auth in EE
begin
  require 'openc3-enterprise/controllers/auth_controller'
rescue LoadError
  class AuthController < ApplicationController
    def token_exists
      result = OpenC3::AuthModel.is_set?
      render :json => {
        result: result
      }
    end

    def verify
      result = OpenC3::AuthModel.verify(params[:token])
      render :json => {
        result: result
      }
    end

    def set
      result = OpenC3::AuthModel.set(params[:token], params[:old_token])
      OpenC3::Logger.info("Password changed", user: user_info(request.headers['HTTP_AUTHORIZATION']))
      render :json => {
        result: result
      }
    end
  end
end
