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

require 'fileutils'
require 'cosmos/models/plugin_model'

class PluginsController < ModelController
  def initialize
    @model_class = Cosmos::PluginModel
    @variables = nil
  end

  # Add a new plugin
  def create
    authorize(permission: 'admin', scope: params[:scope], token: params[:token])
    file = params[:plugin]
    if file
      temp_dir = Dir.mktmpdir
      begin
        gem_file_path = temp_dir + '/' + file.original_filename
        FileUtils.cp(file.tempfile.path, gem_file_path)
        render :json => Cosmos::PluginModel.install_phase1(gem_file_path, @variables, scope: params[:scope])
      rescue
        head :internal_server_error
      ensure
        FileUtils.remove_entry(temp_dir) if temp_dir and File.exist?(temp_dir)
      end
    else
      head :internal_server_error
    end
  end

  def update
    # Grab the existing plugin we're updating so we can display existing variables
    @variables = @model_class.get(name: params[:id], scope: params[:scope])['variables']
    destroy()
    create()
    @variables = nil
  end

  def install
    authorize(permission: 'admin', scope: params[:scope], token: params[:token])
    begin
      render :json => Cosmos::PluginModel.install_phase2(params[:id], JSON.parse(params[:variables]), scope: params[:scope])
    rescue
      head :internal_server_error
    end
  end
end
