require 'thread'

class LimitsEventChannel < ApplicationCable::Channel
  def initialize(*args)
    super(*args)
    @mutex = Mutex.new
    @subscriber_count = 0
  end

  def subscribed
    stream_from "limits"
    @mutex.synchronize do
      @thread ||= LimitsEventBroadcastThread.new
      @subscriber_count += 1
    end
  end

  def unsubscribed
    @mutex.synchronize do
      @subscriber_count -= 1
      if @subscriber_count <= 0
        @thread.kill
        @subscriber_count = 0
      end
    end
  end
end
