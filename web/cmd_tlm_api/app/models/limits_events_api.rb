# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'topics_thread'

class LimitsEventsApi
  def initialize(uuid, channel, history_count = 0, scope:)
    topics = ["#{scope}__cosmos_limits_events"]
    @thread = TopicsThread.new(topics, channel, history_count)
    @thread.start
  end

  def kill
    @thread.stop
  end
end

# class FakeChannel
#   def transmit(*args)
#     STDOUT.puts args.inspect
#   end
# end

# MessagesApi.new("Ryan", FakeChannel.new, 10, scope: "DEFAULT")
# sleep(20)
