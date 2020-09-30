class StreamingChannel < ApplicationCable::Channel
  def subscribed
    stream_from uuid
    @broadcasters ||= {}
    @broadcasters[uuid] = StreamingApi.new(uuid, self)
  end

  def unsubscribed
    stop_all_streams()
    if @broadcasters[uuid]
      @broadcasters[uuid].kill
      @broadcasters[uuid] = nil
    end
    @broadcasters.delete(uuid)
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
    unless data['scope']
      transmit error: 'scope is required'
      # TODO: This feels weird but ActionCable is new ... better way?
      reject # Sets the rejected state on the connection
      reject_subscription # Calls the 'rejected' method on the frontend
      result = false
    end
    unless data['items'] and data['items'].length > 0
      transmit error: 'items is required'
      # TODO: This feels weird but ActionCable is new ... better way?
      reject # Sets the rejected state on the connection
      reject_subscription # Calls the 'rejected' method on the frontend
      result = false
    end
    if data["start_time"]
      # TODO: Currently don't support start_time greater than now
      # Is there a use-case to wait for the start time and then start streaming?
      if data["start_time"].to_i > Time.now.to_nsec_from_epoch
        transmit error: 'start_time greater than current time'
        # TODO: This feels weird but ActionCable is new ... better way?
        reject # Sets the rejected state on the connection
        reject_subscription # Calls the 'rejected' method on the frontend
        result = false
      end
    end
    result
  end
end
