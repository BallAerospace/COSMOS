require 'cosmos/models/scope_model'

class ScopesController < ModelController
  def initialize
    @model_class = Cosmos::ScopeModel
  end
end
