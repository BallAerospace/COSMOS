Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  post "/api" => "api#api"
  get "/screen/:target" => "api#screens"
  get "/screen/:target/:screen" => "api#screen"
  post "/admin/upload" => "admin#upload"
end
