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
    render :json => Script.all(params[:scope])
  end

  def body
    file = Script.body(params[:scope], params[:name])
    if file
      results = { "contents" => file }
      if params[:name].include?('suite')
        results['suites'] = Script.process_suite(params[:name], file)
      end
      render :json => results
    else
      head :not_found
    end
  end

  def create
    success = Script.create(params[:scope], params[:name], params[:text])
    if success
      results = {}
      if params[:name].include?('suite')
        results['suites'] = Script.process_suite(params[:name], params[:text])
      end
      render :json => results
    else
      head :error
    end
  end

  def run
    suiteRunner = params[:suiteRunner] ? params[:suiteRunner].as_json : nil
    running_script_id = Script.run(params[:scope], params[:name], suiteRunner, params[:disconnect] == 'disconnect')
    if running_script_id
      render :plain => running_script_id.to_s
    else
      head :not_found
    end
  end

  def destroy
    destroyed = Script.destroy(params[:scope], params[:name])
    if destroyed
      head :ok
    else
      head :not_found
    end
  end

  def syntax
    script = Script.syntax(request.body.read)
    if script
      render :json => script
    else
      head :error
    end
  end
end
