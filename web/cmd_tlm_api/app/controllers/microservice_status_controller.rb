require 'cosmos/models/microservice_status_model'

class MicroserviceStatusController < ModelController
  def initialize
    @model_class = Cosmos::MicroserviceStatusModel
  end
end