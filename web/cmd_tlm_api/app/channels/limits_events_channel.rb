class LimitsEventsChannel < ApplicationCable::Channel
  def subscribed
    stream_from uuid
    @broadcasters ||= {}
    @broadcasters[uuid] = LimitsEventsApi.new(uuid, self, params['history_count'], scope: params['scope'], token: params['token'])
  end

  def unsubscribed
    @broadcasters[uuid].kill
    @broadcasters[uuid] = nil
    @broadcasters.delete(uuid)
  end
end
