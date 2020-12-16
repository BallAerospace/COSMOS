class ScriptsController < ApplicationController
  def index
    render :json => Script.all(params[:scope])
  end

  # def show
  #   script = Script.find(params[:scope], params[:name])
  #   if script
  #     render :json => script
  #   else
  #     head :not_found
  #   end
  # end

  def body
    file = Script.body(params[:scope], params[:name])
    if file
      render :json => file
    else
      head :not_found
    end
  end

  def create
    success = Script.create(params[:scope], params[:name], params[:text])
    if success
      head :ok
    else
      head :error
    end
  end

  def run
    suiteRunner = params[:suiteRunner] ? params[:suiteRunner].as_json : nil
    running_script_id = Script.run(params[:scope], params[:name], suiteRunner, params[:disconnect] == 'disconnect')
    if running_script_id
      render :plain => running_script_id.to_s
    else
      head :not_found
    end
  end

  def destroy
    destroyed = Script.destroy(params[:scope], params[:name])
    if destroyed
      head :ok
    else
      head :not_found
    end
  end

  def syntax
    script = Script.syntax(request.body.read)
    if script
      render :json => script
    else
      head :error
    end
  end
end
