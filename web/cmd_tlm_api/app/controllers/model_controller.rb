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

require 'cosmos/models/gem_model'

class ModelController < ApplicationController
  def index
    authorize(permission: 'system', scope: params[:scope], token: params[:token])
    render :json => @model_class.names(scope: params[:scope])
  end

  def create
    authorize(permission: 'admin', scope: params[:scope], token: params[:token])
    model = @model_class.from_json(params[:json], scope: params[:scope])
    model.update
    head :ok
  end

  def show
    authorize(permission: 'system', scope: params[:scope], token: params[:token])
    if params[:id].downcase == 'all'
      render :json => @model_class.all(scope: params[:scope])
    else
      render :json => @model_class.get(name: params[:id], scope: params[:scope])
    end
  end

  def update
    create()
  end

  def destroy
    authorize(permission: 'admin', scope: params[:scope], token: params[:token])
    @model_class.new(name: params[:id], scope: params[:scope]).destroy
  end
end
