require 'cosmos/models/model'

module Cosmos
  class ScopeModel < Model
    PRIMARY_KEY = 'cosmos_scopes'

    def initialize(name:, updated_at: nil, scope: nil)
      super(PRIMARY_KEY, name: name, updated_at: updated_at)
    end

    def as_json
      { 'name' => @name,
        'updated_at' => @updated_at
      }
    end

    def as_config
      "SCOPE #{@name}\n"
    end

    def self.handle_config(primary_key, parser, model, keyword, parameters)
      case keyword
      when 'SCOPE'
        parser.verify_num_parameters(1, 1, "SCOPE <Name>")
        return self.new(name: parameters[0])
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Scope: #{keyword} #{parameters.join(" ")}")
      end
      return nil
    end

    def self.get(name:, scope: nil)
      super(PRIMARY_KEY, name: name)
    end

    def self.names(scope: nil)
      super(PRIMARY_KEY)
    end

    def self.all(scope: nil)
      super(PRIMARY_KEY)
    end
  end
end