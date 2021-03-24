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

require 'cosmos/topics/topic'

module Cosmos
  class NotificationsTopic < Topic
    def self.write_notification(notification, scope:)
      msg_hash = { time: notification.time.to_nsec_from_epoch,
        urgency: notification.urgency,
        title: notification.title,
        url: notification.url,
        body: notification.body }
      Store.write_topic("#{scope}__cosmos_notifications", msg_hash)
    end
  end
end
