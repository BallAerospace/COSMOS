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
      result = Cosmos::GemModel.put(file)
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
    if params[:gem]
      result = Cosmos::GemModel.destroy(params[:gem])
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
