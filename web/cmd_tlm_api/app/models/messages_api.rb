# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require_relative 'topics_thread'
require 'cosmos/utilities/authorization'

class MessagesApi
  include Cosmos::Authorization

  def initialize(uuid, channel, history_count = 0, scope: nil, token: nil)
    authorize(permission: 'system', scope: scope, token: token)
    if scope
      topics = ["#{scope}__cosmos_log_messages"]
    else
      topics = ["cosmos_log_messages"]
    end
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

# MessagesApi.new("Ryan", FakeChannel.new, nil)
# sleep(20)
