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

require 'cosmos/utilities/authorization'
class ApplicationController < ActionController::API
  include Cosmos::Authorization

  private

  # Authorize and rescue the possible execeptions
  # @return [Boolean] true if authorize successful
  def authorization(permission)
    begin
      authorize(
        permission: permission,
        scope: params[:scope],
        token: request.headers['HTTP_AUTHORIZATION'],
      )
    rescue Cosmos::AuthError => e
      render(json: { status: 'error', message: e.message }, status: 401) and
        return false
    rescue Cosmos::ForbiddenError => e
      render(json: { status: 'error', message: e.message }, status: 403) and
        return false
    end
    true
  end
end
