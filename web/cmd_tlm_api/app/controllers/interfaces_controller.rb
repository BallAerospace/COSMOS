require 'cosmos/models/interface_model'

class InterfacesController < ModelController
  def initialize
    @model_class = Cosmos::InterfaceModel
  end
end