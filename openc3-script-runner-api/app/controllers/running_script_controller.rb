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

class RunningScriptController < ApplicationController
  def index
    return unless authorization('script_view')
    render :json => RunningScript.all
  end

  def show
    return unless authorization('script_view')
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      render :json => running_script
    else
      head :not_found
    end
  end

  def stop
    return unless authorization('script_run')
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      ActionCable.server.broadcast("cmd-running-script-channel:#{params[:id]}", "stop")
      OpenC3::Logger.info("Script stopped: #{running_script}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      head :ok
    else
      head :not_found
    end
  end

  def delete
    return unless authorization('script_run')
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      RunningScript.delete(params[:id].to_i)
      OpenC3::Logger.info("Script deleted: #{running_script}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      head :ok
    else
      head :not_found
    end
  end

  def pause
    return unless authorization('script_run')
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      ActionCable.server.broadcast("cmd-running-script-channel:#{params[:id]}", "pause")
      OpenC3::Logger.info("Script paused: #{running_script}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      head :ok
    else
      head :not_found
    end
  end

  def retry
    return unless authorization('script_run')
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      ActionCable.server.broadcast("cmd-running-script-channel:#{params[:id]}", "retry")
      OpenC3::Logger.info("Script retried: #{running_script}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      head :ok
    else
      head :not_found
    end
  end

  def go
    return unless authorization('script_run')
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      ActionCable.server.broadcast("cmd-running-script-channel:#{params[:id]}", "go")
      OpenC3::Logger.info("Script resumed: #{running_script}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      head :ok
    else
      head :not_found
    end
  end

  def step
    return unless authorization('script_run')
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      ActionCable.server.broadcast("cmd-running-script-channel:#{params[:id]}", "step")
      OpenC3::Logger.info("Script stepped: #{running_script}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      head :ok
    else
      head :not_found
    end
  end

  def prompt
    return unless authorization('script_run')
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      if params[:password]
        # TODO: ActionCable is logging this ... probably shouldn't
        ActionCable.server.broadcast("cmd-running-script-channel:#{params[:id]}", { method: params[:method], password: params[:password], prompt_id: params[:prompt_id] })
      else
        ActionCable.server.broadcast("cmd-running-script-channel:#{params[:id]}", { method: params[:method], answer: params[:answer], prompt_id: params[:prompt_id] })
      end
      OpenC3::Logger.info("Script prompt action #{params[:method]}: #{running_script}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      head :ok
    else
      head :not_found
    end
  end

  def method
    return unless authorization('script_run')
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      ActionCable.server.broadcast("cmd-running-script-channel:#{params[:id]}", { method: params[:method], args: params[:args], prompt_id: params[:prompt_id] })
      OpenC3::Logger.info("Script method action #{params[:method]}: #{running_script}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      head :ok
    else
      head :not_found
    end
  end
end
