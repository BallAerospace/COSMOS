class ScriptsController < ApplicationController

  def index
    render :json => Script.all(params[:bucket])
  end

  def show
    script = Script.find(params[:name], params[:bucket])
    if script
      render :json => script
    else
      head :not_found
    end
  end

  def body
    text = Script.body(params[:name], params[:bucket])
    if text
      render :plain => text
    else
      head :not_found
    end
  end

  def create
    success = Script.create(params[:name], params[:bucket], request.body.read)
    if success
      head :ok
    else
      head :error
    end
  end

  def run
    running_script_id = Script.run(params[:name], params[:bucket], params[:disconnect] == 'disconnect')
    if running_script_id
      render :plain => running_script_id.to_s
    else
      head :not_found
    end
  end

  def destroy
    destroyed = Script.destroy(params[:name], params[:bucket])
    if destroyed
      head :ok
    else
      head :not_found
    end
  end

end
