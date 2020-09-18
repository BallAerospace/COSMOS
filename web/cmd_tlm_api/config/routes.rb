Rails.application.routes.draw do
  scope :admin do
    resources :gems
    resources :microservices
    resources :tools
    resources :scopes
    resources :plugins
  end
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  post "/api" => "api#api"
  get "/screen/:target" => "api#screens"
  get "/screen/:target/:screen" => "api#screen"
end
