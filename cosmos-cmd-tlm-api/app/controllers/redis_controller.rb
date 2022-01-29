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

class RedisController < ApplicationController
  DISALLOWED_COMMANDS = [
    'AUTH' # Because changing the Redis ACL user will break cmd-tlm-api
  ]

  def execute_raw
    begin
      authorize(permission: 'superadmin', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end

    args = request.body.read.split(' ').compact

    # Check that we allow this command
    command = args[0].upcase
    if DISALLOWED_COMMANDS.include? command
      render(:json => { :status => 'error', :message => "The #{command} command is not allowed." }, :status => 422) and return
    end

    result = Cosmos::Store.execute_raw(args)
    Cosmos::Logger.info("Redis command executed: #{args} - with result #{result}", user: user_info(request.headers['HTTP_AUTHORIZATION']))
    render :json => { :result => result }, :status => 201
  end
end
