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

require 'action_cable/channel/streams'
require 'action_cable/subscription_adapter/redis'

# Monkey Patches to Make ActionCable output synchronous
# Based on Rails 6.1
module ActionCable
  module SubscriptionAdapter
    class Redis < Base # :nodoc:
      private
        class Listener < SubscriberMap
          def invoke_callback(callback, message)
            callback.call message
          end
        end
    end
  end

  module Channel
    module Streams
      private
        def worker_pool_stream_handler(broadcasting, user_handler, coder: nil)
          handler = stream_handler(broadcasting, user_handler, coder: coder)

          -> message do
            # Make this synchronous to force in order messaging until we can come up with something
            # fancier that is asynchronous
            handler.call(message)
          end
        end
    end
  end
end

module ApplicationCable
  class Channel < ActionCable::Channel::Base
  end
end
