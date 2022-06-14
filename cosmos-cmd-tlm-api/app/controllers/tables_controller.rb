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

require 'base64'

class TablesController < ApplicationController
  def index
    return unless authorization('system')
    render json: Table.all(params[:scope])
  end

  def body
    return unless authorization('system')
    file = Table.body(params[:scope], params[:name])
    if file
      results = {}

      if File.extname(params[:name]) == '.txt'
        results = { 'contents' => file }
      else
        locked = Table.locked?(params[:scope], params[:name])
        unless locked
          user = user_info(request.headers['HTTP_AUTHORIZATION'])
          username = user['name']

          # Generic name that makes sense in the lock toast (EE has the actual username)
          username ||= 'Someone else'
          Table.lock(params[:scope], params[:name], username)
        end
        results = { 'contents' => Base64.encode64(file), 'locked' => locked }
      end
      render json: results
    else
      head :not_found
    end
  end

  def load
    return unless authorization('system')
    table = Table.load(params[:scope], params[:binary], params[:definition])
    if table
      render json: table
    else
      head :not_found
    end
  end

  def save
    return unless authorization('system')
    begin
      Table.save(params[:scope], params[:binary], params[:definition], params[:tables])
      head :ok
    rescue => e
      render(json: { status: 'error', message: e.message }, status: 400)
    end
  end

  def save_as
    return unless authorization('system')
    begin
      Table.save_as(params[:scope], params[:name], params[:new_name])
      head :ok
    rescue => e
      render(json: { status: 'error', message: e.message }, status: 400)
    end
  end

  def generate
    return unless authorization('system')
    begin
      filename = Table.generate(params[:scope], params[:name], params[:contents])
      if filename
        results = { 'filename' => filename }
        render json: results
      else
        head :internal_server_error
      end
    rescue Exception => e
      render(json: { status: 'error', message: e.message }, status: 500) and
        return
    end
  end

  def report
    return unless authorization('system')
    table = Table.report(params[:scope], params[:binary], params[:definition])
    if table
      render json: table
    else
      head :not_found
    end
  end

  def lock
    return unless authorization('system')
    user = user_info(request.headers['HTTP_AUTHORIZATION'])
    username = user['name']

    # Generic name that makes sense in the lock toast (EE has the actual username)
    username ||= 'Someone else'
    Table.lock(params[:scope], params[:name], username)
    render status: 200
  end

  def unlock
    return unless authorization('system')
    user = user_info(request.headers['HTTP_AUTHORIZATION'])
    username = user['name']
    username ||= 'Someone else'
    locked_by = Table.locked?(params[:scope], params[:name])
    Table.unlock(params[:scope], params[:name]) if username == locked_by
    render status: 200
  end

  def destroy
    return unless authorization('system')
    destroyed = Table.destroy(params[:scope], params[:name])
    if destroyed
      Cosmos::Logger.info(
        "Table destroyed: #{params[:name]}",
        scope: params[:scope],
        user: user_info(request.headers['HTTP_AUTHORIZATION']),
      )
      head :ok
    else
      head :not_found
    end
  end
end
