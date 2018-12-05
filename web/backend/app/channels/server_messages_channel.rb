require 'thread'

class ServerMessagesChannel < ApplicationCable::Channel
  def initialize(*args)
    super(*args)
    @mutex = Mutex.new
    @subscriber_count = 0
  end

  def subscribed
    stream_from "server_message"
    @mutex.synchronize do
      @thread ||= ServerMessagesBroadcastThread.new
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
