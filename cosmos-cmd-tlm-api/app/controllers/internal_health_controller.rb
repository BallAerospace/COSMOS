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
require 'cosmos/models/info_model'
require 'cosmos/models/ping_model'


class InternalHealthController < ApplicationController
  # InternalHealthController is designed to check the health of Cosmos. Health
  # will return the Redis info method and can be expanded on. From here the
  # user can see how Redis is and determain health.

  def health
    begin
      authorize(permission: 'system', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    begin
      render :json => { :redis => Cosmos::InfoModel.get() }, :status => 200
    rescue => e
      render :json => { :status => 'error', :message => e.message, :type => e.class }, :status => 500
    end
  end

end