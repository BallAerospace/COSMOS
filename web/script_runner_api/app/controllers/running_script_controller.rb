class RunningScriptController < ApplicationController

  def index
    render :json => RunningScript.all
  end

  def show
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      render :json => running_script
    else
      head :not_found
    end
  end

  def stop
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      ActionCable.server.broadcast("cmd-running-script-channel:#{params[:id]}", "stop")
      head :ok
    else
      head :not_found
    end
  end

  def pause
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      ActionCable.server.broadcast("cmd-running-script-channel:#{params[:id]}", "pause")
      head :ok
    else
      head :not_found
    end
  end

  def go
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      ActionCable.server.broadcast("cmd-running-script-channel:#{params[:id]}", "go")
      head :ok
    else
      head :not_found
    end
  end

  def prompt
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      ActionCable.server.broadcast("cmd-running-script-channel:#{params[:id]}", { method: params[:method], result: params[:answer] })
      head :ok
    else
      head :not_found
    end
  end

  def method
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      ActionCable.server.broadcast("cmd-running-script-channel:#{params[:id]}", { method: params[:method] })
      head :ok
    else
      head :not_found
    end
  end
end
