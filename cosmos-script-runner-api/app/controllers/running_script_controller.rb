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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

class RunningScriptController < ApplicationController
  def index
    begin
      authorize(permission: 'script_view', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    render :json => RunningScript.all
  end

  def show
    begin
      authorize(permission: 'script_view', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      render :json => running_script
    else
      head :not_found
    end
  end

  def stop
    begin
      authorize(permission: 'script_run', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      ActionCable.server.broadcast("cmd-running-script-channel:#{params[:id]}", "stop")
      Cosmos::Logger.info("Script stopped: #{running_script}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      head :ok
    else
      head :not_found
    end
  end

  def delete
    begin
      authorize(permission: 'script_run', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      RunningScript.delete(params[:id].to_i)
      Cosmos::Logger.info("Script deleted: #{running_script}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      head :ok
    else
      head :not_found
    end
  end

  def pause
    begin
      authorize(permission: 'script_run', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      ActionCable.server.broadcast("cmd-running-script-channel:#{params[:id]}", "pause")
      Cosmos::Logger.info("Script paused: #{running_script}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      head :ok
    else
      head :not_found
    end
  end

  def retry
    begin
      authorize(permission: 'script_run', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      ActionCable.server.broadcast("cmd-running-script-channel:#{params[:id]}", "retry")
      Cosmos::Logger.info("Script retried: #{running_script}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      head :ok
    else
      head :not_found
    end
  end

  def go
    begin
      authorize(permission: 'script_run', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      ActionCable.server.broadcast("cmd-running-script-channel:#{params[:id]}", "go")
      Cosmos::Logger.info("Script resumed: #{running_script}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      head :ok
    else
      head :not_found
    end
  end

  def step
    begin
      authorize(permission: 'script_run', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      ActionCable.server.broadcast("cmd-running-script-channel:#{params[:id]}", "step")
      Cosmos::Logger.info("Script stepped: #{running_script}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      head :ok
    else
      head :not_found
    end
  end

  def prompt
    begin
      authorize(permission: 'script_run', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      if params[:password]
        # TODO: ActionCable is logging this ... probably shouldn't
        ActionCable.server.broadcast("cmd-running-script-channel:#{params[:id]}", { method: params[:method], password: params[:password], prompt_id: params[:prompt_id] })
      else
        ActionCable.server.broadcast("cmd-running-script-channel:#{params[:id]}", { method: params[:method], result: params[:answer], prompt_id: params[:prompt_id] })
      end
      Cosmos::Logger.info("Script prompt action #{params[:method]}: #{running_script}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      head :ok
    else
      head :not_found
    end
  end

  def method
    begin
      authorize(permission: 'script_run', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    running_script = RunningScript.find(params[:id].to_i)
    if running_script
      ActionCable.server.broadcast("cmd-running-script-channel:#{params[:id]}", { method: params[:method], args: params[:args], prompt_id: params[:prompt_id] })
      Cosmos::Logger.info("Script method action #{params[:method]}: #{running_script}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      head :ok
    else
      head :not_found
    end
  end
end
