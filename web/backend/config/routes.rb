Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  post '/api', to: "api#apicmd"
  mount ActionCable.server => '/cable'
end
