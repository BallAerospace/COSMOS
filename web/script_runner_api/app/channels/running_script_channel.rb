class RunningScriptChannel < ApplicationCable::Channel
  def subscribed
    stream_from "running-script-channel:#{params[:id]}"
  end
end