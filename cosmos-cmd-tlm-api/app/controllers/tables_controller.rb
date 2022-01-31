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

class TablesController < ModelController
  def index
    begin
      authorize(
        permission: 'system',
        scope: params[:scope],
        token: request.headers['HTTP_AUTHORIZATION'],
      )
    rescue Cosmos::AuthError => e
      render(json: { status: 'error', message: e.message }, status: 401) and
        return
    rescue Cosmos::ForbiddenError => e
      render(json: { status: 'error', message: e.message }, status: 403) and
        return
    end
    render json: Table.all(params[:scope])
  end

  def body
    begin
      authorize(
        permission: 'system',
        scope: params[:scope],
        token: request.headers['HTTP_AUTHORIZATION'],
      )
    rescue Cosmos::AuthError => e
      render(json: { status: 'error', message: e.message }, status: 401) and
        return
    rescue Cosmos::ForbiddenError => e
      render(json: { status: 'error', message: e.message }, status: 403) and
        return
    end
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
    begin
      authorize(
        permission: 'system',
        scope: params[:scope],
        token: request.headers['HTTP_AUTHORIZATION'],
      )
    rescue Cosmos::AuthError => e
      render(json: { status: 'error', message: e.message }, status: 401) and
        return
    rescue Cosmos::ForbiddenError => e
      render(json: { status: 'error', message: e.message }, status: 403) and
        return
    end
    table = Table.load(params[:scope], params[:binary], params[:definition])
    if table
      render json: table
    else
      head :not_found
    end
  end

  def save
    begin
      authorize(
        permission: 'system',
        scope: params[:scope],
        token: request.headers['HTTP_AUTHORIZATION'],
      )
    rescue Cosmos::AuthError => e
      render(json: { status: 'error', message: e.message }, status: 401) and
        return
    rescue Cosmos::ForbiddenError => e
      render(json: { status: 'error', message: e.message }, status: 403) and
        return
    end
    success = Table.save(params[:scope], params[:binary], params[:definition], params[:table])
    if success
      head :ok
    else
      head :internal_server_error
    end
  end

  def generate
    begin
      authorize(
        permission: 'system',
        scope: params[:scope],
        token: request.headers['HTTP_AUTHORIZATION'],
      )
    rescue Cosmos::AuthError => e
      render(json: { status: 'error', message: e.message }, status: 401) and
        return
    rescue Cosmos::ForbiddenError => e
      render(json: { status: 'error', message: e.message }, status: 403) and
        return
    end
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

  def download
    begin
      authorize(
        permission: 'system',
        scope: params[:scope],
        token: request.headers['HTTP_AUTHORIZATION'],
      )
    rescue Cosmos::AuthError => e
      render(json: { status: 'error', message: e.message }, status: 401) and
        return
    rescue Cosmos::ForbiddenError => e
      render(json: { status: 'error', message: e.message }, status: 403) and
        return
    end
    begin
      puts params
      # Cosmos::TableModel.get(params[])
    rescue Exception => e
      render(json: { status: 'error', message: e.message }, status: 500) and
        return
    end
  end

  def lock
    begin
      authorize(
        permission: 'system',
        scope: params[:scope],
        token: request.headers['HTTP_AUTHORIZATION'],
      )
    rescue Cosmos::AuthError => e
      render(json: { status: 'error', message: e.message }, status: 401) and
        return
    rescue Cosmos::ForbiddenError => e
      render(json: { status: 'error', message: e.message }, status: 403) and
        return
    end
    user = user_info(request.headers['HTTP_AUTHORIZATION'])
    username = user['name']

    # Generic name that makes sense in the lock toast (EE has the actual username)
    username ||= 'Someone else'
    Table.lock(params[:scope], params[:name], username)
    render status: 200
  end

  def unlock
    begin
      authorize(
        permission: 'system',
        scope: params[:scope],
        token: request.headers['HTTP_AUTHORIZATION'],
      )
    rescue Cosmos::AuthError => e
      render(json: { status: 'error', message: e.message }, status: 401) and
        return
    rescue Cosmos::ForbiddenError => e
      render(json: { status: 'error', message: e.message }, status: 403) and
        return
    end
    user = user_info(request.headers['HTTP_AUTHORIZATION'])
    username = user['name']
    username ||= 'Someone else'
    locked_by = Table.locked?(params[:scope], params[:name])
    Table.unlock(params[:scope], params[:name]) if username == locked_by
    render status: 200
  end

  def destroy
    begin
      authorize(
        permission: 'system',
        scope: params[:scope],
        token: request.headers['HTTP_AUTHORIZATION'],
      )
    rescue Cosmos::AuthError => e
      render(json: { status: 'error', message: e.message }, status: 401) and
        return
    rescue Cosmos::ForbiddenError => e
      render(json: { status: 'error', message: e.message }, status: 403) and
        return
    end
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
