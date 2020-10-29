require 'cosmos/models/model'

module Cosmos
  class TargetModel < Model
    PRIMARY_KEY = 'cosmos_targets'

    def initialize(
      name:,
      scope: nil)
      super("#{scope}__#{PRIMARY_KEY}", name: name)
    end

    def as_json
      {
        'name' => @name,
      }
    end

    def as_config
      "TARGET #{@name}\n"
    end

    def self.handle_config(primary_key, parser, model, keyword, parameters)
      case keyword
      when 'TARGET'
        parser.verify_num_parameters(1, 1, "TARGET <Name>")
        return self.new(name: parameters[0])
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Target: #{keyword} #{parameters.join(" ")}")
      end
      return nil
    end

    def self.from_json(json, scope: nil)
      json = JSON.parse(json) if String === json
      self.new("#{scope}__#{PRIMARY_KEY}", **json)
    end

    def self.get(name:, scope: nil, token: nil)
      super("#{scope}__#{PRIMARY_KEY}", name: name, scope: scope, token: token)
    end

    def self.names(scope: nil, token: nil)
      super("#{scope}__#{PRIMARY_KEY}", scope: scope, token: token)
    end

    def self.all(scope: nil, token: nil)
      super("#{scope}__#{PRIMARY_KEY}", scope: scope, token: token)
    end
  end
end