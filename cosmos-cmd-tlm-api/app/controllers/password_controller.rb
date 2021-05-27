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

require 'cosmos'
require 'cosmos/models/password_model'

class PasswordController < ApplicationController

  def exists
    result = Cosmos::PasswordModel.is_set?
    render :json => {
      result: result
    }
  end

  def verify
    result = Cosmos::PasswordModel.verify(params[:password])
    render :json => {
      result: result
    }
  end

  def set
    result = Cosmos::PasswordModel.set(params[:password])
    render :json => {
      result: result
    }
  end

  def reset
    result = Cosmos::PasswordModel.reset(params[:password], params[:recovery_token])
    render :json => {
      result: result
    }
  end

end
