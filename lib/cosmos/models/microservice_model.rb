require 'cosmos/models/model'

module Cosmos
  class MicroserviceModel < Model
    PRIMARY_KEY = 'cosmos_microservices'

    attr_accessor :cmd_line
    attr_accessor :options

    def initialize(
      name:,
      cmd_line: nil,
      options: [],
      scope: nil)
      super(PRIMARY_KEY, name: name)
      @cmd_line = cmd_line
      @options = options
    end

    def as_json
      {
        'name' => @name,
        'cmd_line' => @cmd_line,
        'options' => @options
      }
    end

    def as_config
      result = "MICROSERVICE #{@name}\n"
      result << "  CMD_LINE #{@cmd_line.join(' ')}\n"
      @options.each do |option|
        result << "  OPTION #{option.join(" ")}\n"
      end
      result
    end

    def self.handle_config(primary_key, parser, model, keyword, parameters)
      case keyword
      when 'MICROSERVICE'
        parser.verify_num_parameters(1, 1, "MICROSERVICE <Name>")
        return self.new(name: parameters[0])
      when 'CMD_LINE'
        parser.verify_num_parameters(1, nil, "CMD_LINE <Args>")
        @cmd_line = parameters.dup
      when 'OPTION'
        parser.verify_num_parameters(2, nil, "OPTION <Option Name> <Option Values>")
        @options << parameters.dup
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Microservice: #{keyword} #{parameters.join(" ")}")
      end
      return nil
    end

    def self.from_json(json, scope: nil)
      json = JSON.parse(json) if String === json
      self.new(PRIMARY_KEY, **json)
    end

    def self.get(name:, scope: nil, token: nil)
      super(PRIMARY_KEY, name: name, scope: scope, token: token)
    end

    def self.names(scope: nil, token: nil)
      super(PRIMARY_KEY, scope: scope, token: token)
    end

    def self.all(scope: nil, token: nil)
      super(PRIMARY_KEY, scope: scope, token: token)
    end
  end
end