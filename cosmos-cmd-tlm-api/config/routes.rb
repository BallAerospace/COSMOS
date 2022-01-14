# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

# For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

Rails.application.routes.draw do
  scope "cosmos-api" do
    resources :routers, only: [:index, :create]
    get '/routers/:id', to: 'routers#show', id: /[^\/]+/
    match '/routers/:id', to: 'routers#update', id: /[^\/]+/, via: [:patch, :put]
    delete '/routers/:id', to: 'routers#destroy', id: /[^\/]+/

    resources :interfaces, only: [:index, :create]
    get '/interfaces/:id', to: 'interfaces#show', id: /[^\/]+/
    match '/interfaces/:id', to: 'interfaces#update', id: /[^\/]+/, via: [:patch, :put]
    delete '/interfaces/:id', to: 'interfaces#destroy', id: /[^\/]+/

    resources :targets, only: [:index, :create]
    get '/targets/:id', to: 'targets#show', id: /[^\/]+/
    match '/targets/:id', to: 'targets#update', id: /[^\/]+/, via: [:patch, :put]
    delete '/targets/:id', to: 'targets#destroy', id: /[^\/]+/

    resources :gems, only: [:index, :create]
    get '/gems/:id', to: 'gems#show', id: /[^\/]+/
    match '/gems/:id', to: 'gems#update', id: /[^\/]+/, via: [:patch, :put]
    delete '/gems/:id', to: 'gems#destroy', id: /[^\/]+/

    resources :microservices, only: [:index, :create]
    get '/microservices/:id', to: 'microservices#show', id: /[^\/]+/
    match '/microservices/:id', to: 'microservices#update', id: /[^\/]+/, via: [:patch, :put]
    delete '/microservices/:id', to: 'microservices#destroy', id: /[^\/]+/

    get '/microservice_status/:id', to: 'microservice_status#show', id: /[^\/]+/

    post '/tools/position/:id', to: 'tools#position', id: /[^\/]+/
    resources :tools, only: [:index, :create]
    get '/tools/:id', to: 'tools#show', id: /[^\/]+/
    match '/tools/:id', to: 'tools#update', id: /[^\/]+/, via: [:patch, :put]
    delete '/tools/:id', to: 'tools#destroy', id: /[^\/]+/

    resources :scopes, only: [:index, :create]
    get '/scopes/:id', to: 'scopes#show', id: /[^\/]+/
    match '/scopes/:id', to: 'scopes#update', id: /[^\/]+/, via: [:patch, :put]
    delete '/scopes/:id', to: 'scopes#destroy', id: /[^\/]+/

    resources :roles, only: [:index, :create]
    get '/roles/:id', to: 'roles#show', id: /[^\/]+/
    match '/roles/:id', to: 'roles#update', id: /[^\/]+/, via: [:patch, :put]
    delete '/roles/:id', to: 'roles#destroy', id: /[^\/]+/

    resources :widgets, only: [:index, :create]
    get '/widgets/:id', to: 'widgets#show', id: /[^\/]+/
    match '/widgets/:id', to: 'widgets#update', id: /[^\/]+/, via: [:patch, :put]
    delete '/widgets/:id', to: 'widgets#destroy', id: /[^\/]+/

    resources :permissions, only: [:index]

    post '/plugins/install/:id', to: 'plugins#install', id: /[^\/]+/
    resources :plugins, only: [:index, :create]
    get '/plugins/:id', to: 'plugins#show', id: /[^\/]+/
    match '/plugins/:id', to: 'plugins#update', id: /[^\/]+/, via: [:patch, :put]
    delete '/plugins/:id', to: 'plugins#destroy', id: /[^\/]+/

    resources :environment, only: [:index, :create]
    delete '/environment/:name', to: 'environment#destroy', name: /[^\/]+/

    resources :timeline, only: [:index, :create]
    get '/timeline/:name', to: 'timeline#show', name: /[^\/]+/
    post '/timeline/:name/color', to: 'timeline#color', name: /[^\/]+/
    delete '/timeline/:name', to: 'timeline#destroy', name: /[^\/]+/

    post '/timeline/activities/create', to: 'activity#multi_create'
    post '/timeline/activities/delete', to: 'activity#multi_destroy'

    get '/timeline/:name/count', to: 'activity#count', name: /[^\/]+/
    get '/timeline/:name/activities', to: 'activity#index', name: /[^\/]+/
    post '/timeline/:name/activities', to: 'activity#create', name: /[^\/]+/
    get '/timeline/:name/activity/:id', to: 'activity#show', name: /[^\/]+/, id: /[^\/]+/
    post '/timeline/:name/activity/:id', to: 'activity#event', name: /[^\/]+/, id: /[^\/]+/
    match '/timeline/:name/activity/:id', to: 'activity#update', name: /[^\/]+/, id: /[^\/]+/, via: [:patch, :put]
    delete '/timeline/:name/activity/:id', to: 'activity#destroy', name: /[^\/]+/, id: /[^\/]+/

    get '/autocomplete/reserved-item-names', to: 'script_autocomplete#get_reserved_item_names'
    get '/autocomplete/keywords/:type', to: 'script_autocomplete#get_keywords', type: /[^\/]+/
    get '/autocomplete/data/:type', to: 'script_autocomplete#get_ace_autocomplete_data', type: /[^\/]+/

    get '/storage/download/:object_id', to: 'storage#get_download_presigned_request', object_id: /[^\/]+/
    get '/storage/upload/:object_id', to: 'storage#get_upload_presigned_request', object_id: /[^\/]+/

    post '/tables/download', to: 'tables#download'
    post '/tables/upload', to: 'tables#upload'

    get "/screen/:target" => "api#screens"
    get "/screen/:target/:screen" => "api#screen"
    post "/screen" => "api#screen_save"

    post "/api" => "api#api"

    get "/auth/token-exists" => "auth#token_exists"
    post "/auth/verify" => "auth#verify"
    post "/auth/set" => "auth#set"

    get "/internal/health" => "internal_health#health"
    get "/internal/metrics" => "internal_metrics#index"
    get "/internal/status" => "internal_status#status"

    get "/time" => "time#get_current"
    get "map.json" => "tools#importmap"

    post "/redis/exec" => "redis#execute_raw"
  end
end
