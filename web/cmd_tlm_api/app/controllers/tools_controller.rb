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

require 'cosmos/models/tool_model'

class ToolsController < ModelController
  def initialize
    @model_class = Cosmos::ToolModel
  end

  # Set the tools order in the list -
  # Passed order is an integer index starting with 0 being first in the list
  def order
    authorize(permission: 'admin', scope: params[:scope], token: params[:token])
    @model_class.set_order(name: params[:id], order: params[:order], scope: params[:scope])
    head :ok
  end
end
