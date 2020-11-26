class GemsController < ApplicationController
  # List the installed gems
  def index
    authorize(permission: 'system', scope: params[:scope], token: params[:token])
    render :json => Cosmos::GemModel.names
  end

  # Add a new gem
  def create
    authorize(permission: 'admin', scope: params[:scope], token: params[:token])
    file = params[:gem]
    if file
      temp_dir = Dir.mktmpdir
      result = false
      begin
        gem_file_path = temp_dir + '/' + file.original_filename
        FileUtils.cp(file.tempfile.path, gem_file_path)
        result = Cosmos::GemModel.put(gem_file_path)
      ensure
        FileUtils.remove_entry(temp_dir) if temp_dir and File.exists?(temp_dir)
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
    authorize(permission: 'super_admin', scope: params[:scope], token: params[:token])
    if params[:id]
      result = Cosmos::GemModel.destroy(params[:id])
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
