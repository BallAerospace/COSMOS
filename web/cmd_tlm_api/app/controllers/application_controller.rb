require 'cosmos/utilities/authorization'
class ApplicationController < ActionController::API
  include Cosmos::Authorization
end
