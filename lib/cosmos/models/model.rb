require 'cosmos/utilities/store'
require 'cosmos/config/config_parser'
require 'cosmos/utilities/authorization'

module Cosmos
  class Model
    include Authorization
    extend Authorization

    attr_accessor :name

    def initialize(primary_key, **kw_args)
      @primary_key = primary_key
      @name = kw_args[:name]
      @updated_at = kw_args[:updated_at]
    end

    def create
      #STDOUT.puts "creating #{@primary_key} : #{@name}"
      @updated_at = Time.now.to_nsec_from_epoch
      Store.hset(@primary_key, @name, JSON.generate(self.as_json))
    end

    def update
      create()
    end

    def destroy
      Store.hdel(@primary_key, @name)
    end

    def as_json
      { 'name' => @name,
        'updated_at' => @updated_at }
    end

    def as_config
      ""
    end

    def self.from_json(json, scope: nil)
      json = JSON.parse(json) if String === json
      symbolized = {}
      json.each do |key, value|
        symbolized[key.intern] = value
      end
      self.new(**symbolized, scope: scope)
    end

    def self.get(primary_key, name:)
      JSON.parse(Store.hget(primary_key, name))
    end

    def self.names(primary_key)
      Store.hkeys(primary_key).sort
    end

    def self.all(primary_key)
      hash = Store.hgetall(primary_key)
      hash.each do |key, value|
        hash[key] = JSON.parse(value)
      end
      hash
    end

    def self.handle_config(parser, model, keyword, parameters)
      raise "must be implmented by subclass"
    end

    def self.from_config(primary_key, filename)
      model = nil
      parser = ConfigParser.new
      parser.parse_file(filename) do |keyword, parameters|
        model = self.handle_config(primary_key, parser, model, keyword, parameters)
      end
      model
    end

    def create_erb_binding(config_parser_erb_variables)
      config_parser_erb_variables ||= {}
      config_parser_erb_binding = binding
      config_parser_erb_variables.each do |config_parser_erb_variables_key, config_parser_erb_variables_value|
        config_parser_erb_binding.local_variable_set(config_parser_erb_variables_key.intern, config_parser_erb_variables_value)
      end
      return config_parser_erb_binding
    end
  end
end
