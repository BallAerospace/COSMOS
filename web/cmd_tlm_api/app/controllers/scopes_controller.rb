class ScopesController < ApplicationController
  # List the available scopes
  def index
    render :json => Cosmos::Store.instance.smembers("cosmos_scopes")
  end

  # Add a new scope
  def create
    if params[:scope]
      Cosmos::Store.instance.sadd("cosmos_scopes", params[:scope].to_s.upcase)
    else
      head :internal_server_error
    end
  end

  # Remove a plugin
  def destroy
    if params[:scope]
      STDOUT.puts "Removing scope: #{params[:scope]}"
      Cosmos::Store.instance.srem("cosmos_scopes", params[:scope].to_s.upcase)
    else
      head :internal_server_error
    end
  end
end
