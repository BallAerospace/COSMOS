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

require 'openc3/models/info_model'
require 'openc3/models/ping_model'

# InternalStatusController is designed to check the status of OpenC3. Status will
# check that Redis is up but that does not equal that everything is
# working just that OpenC3 can talk to Redis.
class InternalStatusController < ActionController::Base
  def status
    begin
      render :json => { :status => OpenC3::PingModel.get() }, :status => 200
    rescue => e
      render :json => { :status => 'error', :message => e.message, :type => e.class }, :status => 500
    end
  end
end
