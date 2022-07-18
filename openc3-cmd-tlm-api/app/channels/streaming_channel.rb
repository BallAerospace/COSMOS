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

class StreamingChannel < ApplicationCable::Channel
  def subscribed
    stream_from uuid
    @broadcasters ||= {}
    @broadcasters[uuid] = StreamingApi.new(uuid, self, scope: params['scope'], token: params['token'])
  end

  def unsubscribed
    if @broadcasters[uuid]
      stop_stream_from uuid
      @broadcasters[uuid].kill
      @broadcasters[uuid] = nil
      @broadcasters.delete(uuid)
    end
  end

  # data holds the following keys:
  #   start_time - nsec_since_epoch - null for realtime
  #   end_time - nsec_since_epoch - null for realtime or continue to realtime
  #   items [Array of Item keys] ie ["TLM__INST__ADCS__Q1__RAW"]
  #   scope
  def add(data)
    if validate_data(data)
      @broadcasters[uuid].add(data)
    end
  end

  # data holds the following keys:
  #   items [Array of Item keys] ie ["TLM__INST__ADCS__Q1__RAW"]
  #   scope
  def remove(data)
    if validate_data(data)
      @broadcasters[uuid].remove(data)
    end
  end

  private

  def validate_data(data)
    result = true
    # data['items'] isn't required because we can start out with no items
    # and then add them ... this is how TlmGrapher works
    unless data['scope']
      transmit({error: 'scope is required'})
      # TODO: This feels weird but ActionCable is new ... better way?
      reject() # Sets the rejected state on the connection
      reject_subscription() # Calls the 'rejected' method on the frontend
      result = false
    end
    # if data['start_time']
    #   # TODO: Currently don't support start_time greater than now
    #   # Is there a use-case to wait for the start time and then start streaming?
    #   if data['start_time'].to_i > Time.now.to_nsec_from_epoch
    #     transmit error: 'start_time greater than current time'
    #     # TODO: This feels weird but ActionCable is new ... better way?
    #     reject # Sets the rejected state on the connection
    #     reject_subscription # Calls the 'rejected' method on the frontend
    #     result = false
    #   end
    # end
    result
  end
end
