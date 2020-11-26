require 'fileutils'
require 'cosmos/models/plugin_model'

class PluginsController < ModelController
  def initialize
    @model_class = Cosmos::PluginModel
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
        render :json => Cosmos::PluginModel.install_phase1(gem_file_path, scope: params[:scope])
      rescue
        head :internal_server_error
      ensure
        FileUtils.remove_entry(temp_dir) if temp_dir and File.exists?(temp_dir)
      end
    else
      head :internal_server_error
    end
  end

  def install
    authorize(permission: 'admin', scope: params[:scope], token: params[:token])
    render :json => Cosmos::PluginModel.install_phase2(params[:id], JSON.parse(params[:variables]), scope: params[:scope])
  end
end
