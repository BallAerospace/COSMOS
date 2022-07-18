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

class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_from uuid
    @broadcasters ||= {}
    @broadcasters[uuid] = NotificationsApi.new(uuid, self, params['history_count'], params['start_offset'], scope: params['scope'], token: params['token'])
  end

  def unsubscribed
    if @broadcasters[uuid]
      stop_stream_from uuid
      @broadcasters[uuid].kill
      @broadcasters[uuid] = nil
      @broadcasters.delete(uuid)
    end
  end
end
