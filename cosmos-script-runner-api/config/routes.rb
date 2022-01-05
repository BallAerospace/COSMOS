Rails.application.routes.draw do
  scope "script-api" do
    get  "/scripts" => "scripts#index"
    post "/scripts/syntax" => "scripts#syntax"
    get  "/scripts/*name" => "scripts#body", format: false, defaults: { format: 'html' }
    post "/scripts/*name/run(/:disconnect)" => "scripts#run", format: false, defaults: { format: 'html' }
    post "/scripts/*name/delete" => "scripts#destroy", format: false, defaults: { format: 'html' }
    post "/scripts/*name/lock" => "scripts#lock"
    post "/scripts/*name/unlock" => "scripts#unlock"
    post "/scripts/*name/instrumented" => "scripts#instrumented"
    # Must be last so /run, /delete, etc will match first
    post "/scripts/*name" => "scripts#create", format: false, defaults: { format: 'html' }

    get  "/running-script" => "running_script#index"
    get  "/running-script/:id" => "running_script#show"
    post "/running-script/:id/start" => "running_script#start"
    post "/running-script/:id/stop" => "running_script#stop"
    post "/running-script/:id/pause" => "running_script#pause"
    post "/running-script/:id/retry" => "running_script#retry"
    post "/running-script/:id/go" => "running_script#go"
    post "/running-script/:id/step" => "running_script#step"
    post "/running-script/:id/prompt" => "running_script#prompt"
    post "/running-script/:id/:method" => "running_script#method"
  end
end
