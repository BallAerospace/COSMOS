# encoding: ascii-8bit

# Copyright 2017 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/script'

# Thread used to gather telemetry in realtime and broadcast it
class LimitsEventBroadcastThread
  def initialize
    @shutdown = false
    @process_thread = Thread.new do
      loop do
        break if @shutdown
        @subscription_id = nil
        begin
          @subscription_id = subscribe_limits_events()
          loop do
            break if @shutdown
            event = get_limits_event(@subscription_id)
            ActionCable.server.broadcast("limits", event)
          end
        rescue Exception => err
          begin
            unsubscribe_limits_events(@subscription_id) if @subscription_id
            @subscription_id = nil
          rescue
          end
          sleep(1)
        end
      end
    end
  end

  # Kills the realtime thread
  def kill
    @shutdown = true
    Cosmos.kill_thread(self, @process_thread)
    begin
      unsubscribe_limits_events(@subscription_id) if @subscription_id
      @subscription_id = nil
    rescue
    end
    @process_thread = nil
  end
end
