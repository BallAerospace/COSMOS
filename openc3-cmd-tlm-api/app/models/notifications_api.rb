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

require_relative 'topics_thread'
require 'openc3/utilities/authorization'

class NotificationsApi
  include OpenC3::Authorization

  def initialize(uuid, channel, history_count = 0, start_offset = nil, scope:, token:)
    authorize(permission: 'system', scope: scope, token: token)
    topics = ["#{scope}__openc3_notifications"]
    start_offsets = [start_offset] if start_offset and start_offset != 'undefined'
    @thread = TopicsThread.new(topics, channel, history_count, offsets: start_offsets, transmit_msg_id: true)
    @thread.start
  end

  def kill
    @thread.stop
  end
end
