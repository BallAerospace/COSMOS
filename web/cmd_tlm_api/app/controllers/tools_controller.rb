require 'cosmos/models/tool_model'

class ToolsController < ModelController
  def initialize
    @model_class = Cosmos::ToolModel
  end
end
