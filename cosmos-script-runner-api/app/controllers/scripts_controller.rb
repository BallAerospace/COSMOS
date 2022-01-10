# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
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

class ScriptsController < ApplicationController
  def index
    begin
      authorize(permission: 'script_view', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    render :json => Script.all(params[:scope])
  end

  def body
    begin
      authorize(permission: 'script_view', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    file = Script.body(params[:scope], params[:name])
    if file
      success = true
      locked = Script.locked?(params[:scope], params[:name])
      unless locked
        user = user_info(request.headers['HTTP_AUTHORIZATION'])
        username = user['name']
        username ||= 'Someone else' # Generic name that makes sense in the lock toast in Script Runner (EE has the actual username)
        Script.lock(params[:scope], params[:name], username)
      end
      breakpoints = Script.get_breakpoints(params[:scope], params[:name])
      results = {
        "contents" => file,
        "breakpoints" => breakpoints,
        "locked" => locked
      }
      if params[:name].include?('suite')
        results['suites'], success = Script.process_suite(params[:name], file)
      end
      # If the parsing of the Suite was not successful return a 422 (Unprocessable Entity)
      status = success ? 200 : 422
      render :json => results, status: status
    else
      head :not_found
    end
  end

  def create
    begin
      authorize(permission: 'script_edit', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    success = Script.create(params[:scope], params[:name], params[:text], params[:breakpoints])
    if success
      results = {}
      if params[:name].include?('suite')
        results['suites'], success = Script.process_suite(params[:name], params[:text])
      end
      Cosmos::Logger.info("Script created: #{params[:name]}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION'])) if success
      # If the parsing of the Suite was not successful return a 422 (Unprocessable Entity)
      status = success ? 200 : 422
      render :json => results, status: status
    else
      head :error
    end
  end

  def run
    begin
      authorize(permission: 'script_run', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    suite_runner = params[:suiteRunner] ? params[:suiteRunner].as_json : nil
    disconnect = params[:disconnect] == 'disconnect'
    environment = params[:environment]
    running_script_id = Script.run(params[:scope], params[:name], suite_runner, disconnect, environment)
    if running_script_id
      Cosmos::Logger.info("Script started: #{params[:name]}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      render :plain => running_script_id.to_s
    else
      head :not_found
    end
  end

  def lock
    begin
      authorize(permission: 'script_edit', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    user = user_info(request.headers['HTTP_AUTHORIZATION'])
    username = user['name']
    username ||= 'Someone else' # Generic name that makes sense in the lock toast in Script Runner (EE has the actual username)
    Script.lock(params[:scope], params[:name], username)
    render status: 200
  end

  def unlock
    begin
      authorize(permission: 'script_edit', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    user = user_info(request.headers['HTTP_AUTHORIZATION'])
    username = user['name']
    username ||= 'Someone else'
    locked_by = Script.locked?(params[:scope], params[:name])
    Script.unlock(params[:scope], params[:name]) if username == locked_by
    render status: 200
  end

  def destroy
    begin
      authorize(permission: 'script_edit', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    destroyed = Script.destroy(params[:scope], params[:name])
    if destroyed
      Cosmos::Logger.info("Script destroyed: #{params[:name]}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      head :ok
    else
      head :not_found
    end
  end

  def syntax
    begin
      authorize(permission: 'script_run', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    script = Script.syntax(request.body.read)
    if script
      render :json => script
    else
      head :error
    end
  end

  def instrumented
    begin
      authorize(permission: 'script_view', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    script = Script.instrumented(params[:name], request.body.read)
    if script
      render :json => script
    else
      head :error
    end
  end
end
