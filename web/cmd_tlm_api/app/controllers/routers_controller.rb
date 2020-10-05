require 'cosmos/models/router_model'

class RoutersController < ModelController
  def initialize
    @model_class = Cosmos::RouterModel
  end
end
