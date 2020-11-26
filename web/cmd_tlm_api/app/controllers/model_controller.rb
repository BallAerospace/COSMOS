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
