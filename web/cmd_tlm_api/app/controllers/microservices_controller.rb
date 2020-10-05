require 'cosmos/models/microservice_model'

class MicroservicesController < ModelController
  def initialize
    @model_class = Cosmos::MicroserviceModel
  end
end
