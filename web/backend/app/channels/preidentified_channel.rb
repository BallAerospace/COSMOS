class PreidentifiedChannel < ApplicationCable::Channel
  def subscribed
    stream_from uuid
    @broadcasters ||= {}
    @broadcasters[uuid] = TelemetryGrapherBroadcastThread.new(uuid)
  end

  def unsubscribed
    @broadcasters[uuid].kill
    @broadcasters[uuid] = nil
    @broadcasters.delete(uuid)
  end

  def add_item(data)
    @broadcasters[uuid].add_item(data["item"])
  end
end
