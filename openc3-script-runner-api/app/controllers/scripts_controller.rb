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

require 'json'

class ScriptsController < ApplicationController
  def index
    return unless authorization('script_view')
    render :json => Script.all(params[:scope])
  end

  def body
    return unless authorization('script_view')
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
        contents: file,
        breakpoints: breakpoints,
        locked: locked
      }
      if params[:name].include?('suite')
        results_suites, results_error, success = Script.process_suite(params[:name], file, scope: params[:scope])
        results['suites'] = results_suites
        results['error'] = results_error
        results['success'] = success
      end
      # Using 'render :json => results' results in a raw json string like:
      # {"contents":"{\"json_class\":\"String\",\"raw\":[35,226,128...]}","breakpoints":[],"locked":false}
      render plain: JSON.generate(results)
    else
      head :not_found
    end
  end

  def create
    return unless authorization('script_edit')
    success = Script.create(params[:scope], params[:name], params[:text], params[:breakpoints])
    if success
      results = {}
      if params[:name].include?('suite')
        results_suites, results_error, success = Script.process_suite(params[:name], params[:text], scope: params[:scope])
        results['suites'] = results_suites
        results['error'] = results_error
        results['success'] = success
      end
      OpenC3::Logger.info("Script created: #{params[:name]}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION'])) if success
      render :json => results
    else
      head :error
    end
  end

  def run
    return unless authorization('script_run')
    suite_runner = params[:suiteRunner] ? params[:suiteRunner].as_json(:allow_nan => true) : nil
    disconnect = params[:disconnect] == 'disconnect'
    environment = params[:environment]
    running_script_id = Script.run(params[:scope], params[:name], suite_runner, disconnect, environment)
    if running_script_id
      OpenC3::Logger.info("Script started: #{params[:name]}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      render :plain => running_script_id.to_s
    else
      head :not_found
    end
  end

  def lock
    return unless authorization('script_edit')
    user = user_info(request.headers['HTTP_AUTHORIZATION'])
    username = user['name']
    username ||= 'Someone else' # Generic name that makes sense in the lock toast in Script Runner (EE has the actual username)
    Script.lock(params[:scope], params[:name], username)
    render status: 200
  end

  def unlock
    return unless authorization('script_edit')
    user = user_info(request.headers['HTTP_AUTHORIZATION'])
    username = user['name']
    username ||= 'Someone else'
    locked_by = Script.locked?(params[:scope], params[:name])
    Script.unlock(params[:scope], params[:name]) if username == locked_by
    render status: 200
  end

  def destroy
    return unless authorization('script_edit')
    destroyed = Script.destroy(params[:scope], params[:name])
    if destroyed
      OpenC3::Logger.info("Script destroyed: #{params[:name]}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      head :ok
    else
      head :not_found
    end
  end

  def syntax
    return unless authorization('script_run')
    script = Script.syntax(request.body.read)
    if script
      render :json => script
    else
      head :error
    end
  end

  def instrumented
    return unless authorization('script_view')
    script = Script.instrumented(params[:name], request.body.read)
    if script
      render :json => script
    else
      head :error
    end
  end

  def delete_all_breakpoints
    return unless authorization('script_edit')
    OpenC3::Store.del("#{params[:scope]}__script-breakpoints")
    head :ok
  end
end
