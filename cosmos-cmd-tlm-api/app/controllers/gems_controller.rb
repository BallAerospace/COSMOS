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

class GemsController < ApplicationController
  # List the installed gems
  def index
    return unless authorization('system')
    render :json => Cosmos::GemModel.names
  end

  # Add a new gem
  def create
    return unless authorization('admin')
    file = params[:gem]
    if file
      temp_dir = Dir.mktmpdir
      result = false
      begin
        gem_file_path = temp_dir + '/' + file.original_filename
        FileUtils.cp(file.tempfile.path, gem_file_path)
        result = Cosmos::GemModel.put(gem_file_path, scope: params[:scope])
        Cosmos::Logger.info("Gem created: #{params[:gem]}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      ensure
        FileUtils.remove_entry(temp_dir) if temp_dir and File.exist?(temp_dir)
      end
      if result
        head :ok
      else
        head :internal_server_error
      end
    else
      head :internal_server_error
    end
  end

  # Remove a gem
  def destroy
    return unless authorization('admin')
    if params[:id]
      result = Cosmos::GemModel.destroy(params[:id])
      Cosmos::Logger.info("Gem destroyed: #{params[:id]}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      if result
        head :ok
      else
        head :internal_server_error
      end
    else
      head :internal_server_error
    end
  end
end
