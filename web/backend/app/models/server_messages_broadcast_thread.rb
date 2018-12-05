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

# Thread used to gather server messages in realtime and broadcast them
class ServerMessagesBroadcastThread
  def initialize
    @shutdown = false
    @process_thread = Thread.new do
      loop do
        break if @shutdown
        @subscription_id = nil
        begin
          @subscription_id = subscribe_server_messages()
          loop do
            break if @shutdown
            message = get_server_message(@subscription_id)
            ActionCable.server.broadcast("server_message", message)
          end
        # TODO: This is catching a DRBConnError execution expired Exception
        # which is happening very regularly. It appears to be when back to back
        # messages are on the queue. It results in a bunch of dropped messsages.
        rescue Exception => err
          begin
            unsubscribe_server_messages(@subscription_id) if @subscription_id
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
      unsubscribe_server_messages(@subscription_id) if @subscription_id
      @subscription_id = nil
    rescue
    end
    @process_thread = nil
  end
end
