class ModelController < ApplicationController
  def index
    render :json => @model_class.names(scope: params[:scope])
  end

  def create
    model = @model_class.from_json(params[:json], scope: params[:scope])
    model.update
    head :ok
  end

  def show
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
    @model_class.new(name: params[:id], scope: params[:scope]).destroy
  end
end
