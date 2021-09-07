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


class InternalStatusController < ActionController::Base
  # InternalStatusController is designed to check the status of Cosmos. Status will
  # check that Redis is up but that does not equal that everything is 
  # working just that Cosmos can talk to Redis.

  def status
    begin
      render :json => { 'status' => Cosmos::PingModel.get() }, :status => 200
    rescue => e
      render :json => { 'status' => 'error', 'message' => e.message, 'type' => e.class }, :status => 500
    end
  end

end