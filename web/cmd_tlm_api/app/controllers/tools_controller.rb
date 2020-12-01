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
