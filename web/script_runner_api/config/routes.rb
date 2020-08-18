Rails.application.routes.draw do
  get "/scripts" => "scripts#index"
  get "/scripts/:name" => "scripts#show", :constraints => { :name => /[^\/]+/ }, format: false, defaults: {format: 'html'}
  get "/scripts/:name/body" => "scripts#body", :constraints => { :name => /[^\/]+/ }, format: false, defaults: {format: 'html'}
  post "/scripts/:name" => "scripts#create", :constraints => { :name => /[^\/]+/ }, format: false, defaults: {format: 'html'}
  # post "/scripts/:name/run" => "scripts#run", :constraints => { :name => /[^\/]+/ }, format: false, defaults: {format: 'html'}
  post "/scripts/*name/run" => "scripts#run", format: false, defaults: {format: 'html'}
  post "/scripts/:name/delete" => "scripts#destroy", :constraints => { :name => /[^\/]+/ }, format: false, defaults: {format: 'html'}
  get "/running-script" => "running_script#index"
  get "/running-script/:id" => "running_script#show"
  post "/running-script/:id/start" => "running_script#start"
  post "/running-script/:id/stop" => "running_script#stop"
  post "/running-script/:id/pause" => "running_script#pause"
  post "/running-script/:id/go" => "running_script#go"
  post "/running-script/:id/prompt" => "running_script#prompt"
end
