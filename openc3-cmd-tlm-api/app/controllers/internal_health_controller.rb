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

# InternalHealthController is designed to check the health of OpenC3. Health
# will return the Redis info method and can be expanded on. From here the
# user can see how Redis is and determine health.
class InternalHealthController < ApplicationController
  def health
    return unless authorization('system')
    begin
      render :json => { :redis => OpenC3::InfoModel.get() }, :status => 200
    rescue => e
      render :json => { :status => 'error', :message => e.message, :type => e.class }, :status => 500
    end
  end
end
