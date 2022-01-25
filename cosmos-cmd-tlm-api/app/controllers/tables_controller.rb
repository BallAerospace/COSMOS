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
require 'cosmos'
require 'cosmos/models/table_model'

class TablesController < ModelController
  def upload
    begin
      authorize(permission: 'system', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    table = params[:table]
    if table
      temp_dir = Dir.mktmpdir
      result = false
      begin
        table_file_path = temp_dir + '/' + table.original_filename
        FileUtils.cp(table.tempfile.path, table_file_path)
        result = Cosmos::TableModel.put(table_file_path)
        Cosmos::Logger.info("Table created: #{params[:table]}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
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

  def download
    begin
      authorize(permission: 'system', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    begin
      puts params
      # Cosmos::TableModel.get(params[])
    rescue Exception => e
      render(:json => { :status => 'error', :message => e.message }, :status => 500) and return
    end
  end
end
