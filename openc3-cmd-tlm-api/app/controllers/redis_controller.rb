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

class RedisController < ApplicationController
  DISALLOWED_COMMANDS = [
    'AUTH' # Because changing the Redis ACL user will break cmd-tlm-api
  ]

  def execute_raw
    return unless authorization('admin')

    args = request.body.read.split(' ').compact

    # Check that we allow this command
    command = args[0].upcase
    if DISALLOWED_COMMANDS.include? command
      render(:json => { :status => 'error', :message => "The #{command} command is not allowed." }, :status => 422) and return
    end

    if params[:ephemeral]
      result = OpenC3::EphemeralStore.method_missing(command, args[1..-1])
    else
      result = OpenC3::Store.method_missing(command, args[1..-1])
    end
    OpenC3::Logger.info("Redis command executed: #{args} - with result #{result}", user: user_info(request.headers['HTTP_AUTHORIZATION']))
    render :json => { :result => result }, :status => 201
  end
end
