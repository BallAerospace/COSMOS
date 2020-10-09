require 'cosmos/models/target_model'

class TargetsController < ModelController
  def initialize
    @model_class = Cosmos::TargetModel
  end
end