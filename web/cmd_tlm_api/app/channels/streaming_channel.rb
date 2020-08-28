class StreamingChannel < ApplicationCable::Channel
  def subscribed
    stream_from uuid
    @broadcasters ||= {}
    @broadcasters[uuid] = StreamingApi.new(uuid, self)
  end

  def unsubscribed
    @broadcasters[uuid].kill
    @broadcasters[uuid] = nil
    @broadcasters.delete(uuid)
  end

  # start_time - nsec_since_epoch - null for realtime
  # end_time - nsec_since_epoch - null for realtime or continue to realtime
  # items [Array of Item keys] ie ["TLM__INST__ADCS__Q1__RAW"]
  # scope
  def add(data)
    @broadcasters[uuid].add(data)
  end

  # items [Array of Item keys] ie ["TLM__INST__ADCS__Q1__RAW"]
  # scope
  def remove(data)
    @broadcasters[uuid].remove(data)
  end
end
