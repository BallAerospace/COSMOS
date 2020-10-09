Rails.application.routes.draw do
  resources :routers, only: [:index, :create]
  get '/routers/:id', to: 'routers#show', id: /[^\/]+/
  match '/routers/:id', to: 'routers#update', id: /[^\/]+/, via: [:patch, :put]
  delete '/routers/:id', to: 'routers#delete', id: /[^\/]+/

  resources :interfaces
  get '/interfaces/:id', to: 'interfaces#show', id: /[^\/]+/
  match '/interfaces/:id', to: 'interfaces#update', id: /[^\/]+/, via: [:patch, :put]
  delete '/interfaces/:id', to: 'interfaces#delete', id: /[^\/]+/

  resources :targets
  get '/targets/:id', to: 'targets#show', id: /[^\/]+/
  match '/targets/:id', to: 'targets#update', id: /[^\/]+/, via: [:patch, :put]
  delete '/targets/:id', to: 'targets#delete', id: /[^\/]+/

  resources :gems
  get '/gems/:id', to: 'gems#show', id: /[^\/]+/
  match '/gems/:id', to: 'gems#update', id: /[^\/]+/, via: [:patch, :put]
  delete '/gems/:id', to: 'gems#delete', id: /[^\/]+/

  resources :microservices
  get '/microservices/:id', to: 'microservices#show', id: /[^\/]+/
  match '/microservices/:id', to: 'microservices#update', id: /[^\/]+/, via: [:patch, :put]
  delete '/microservices/:id', to: 'microservices#delete', id: /[^\/]+/

  resources :tools
  get '/tools/:id', to: 'tools#show', id: /[^\/]+/
  match '/tools/:id', to: 'tools#update', id: /[^\/]+/, via: [:patch, :put]
  delete '/tools/:id', to: 'tools#delete', id: /[^\/]+/

  resources :scopes
  get '/scopes/:id', to: 'scopes#show', id: /[^\/]+/
  match '/scopes/:id', to: 'scopes#update', id: /[^\/]+/, via: [:patch, :put]
  delete '/scopes/:id', to: 'scopes#delete', id: /[^\/]+/

  resources :plugins
  get '/plugins/:id', to: 'plugins#show', id: /[^\/]+/
  match '/plugins/:id', to: 'plugins#update', id: /[^\/]+/, via: [:patch, :put]
  delete '/plugins/:id', to: 'plugins#delete', id: /[^\/]+/

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  post "/api" => "api#api"
  get "/screen/:target" => "api#screens"
  get "/screen/:target/:screen" => "api#screen"
end
