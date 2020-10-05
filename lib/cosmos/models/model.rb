require 'cosmos/utilities/store'
require 'cosmos/config/config_parser'

module Cosmos
  class Model
    attr_accessor :name

    def initialize(primary_key, **kw_args)
      @primary_key = primary_key
      @name = kw_args[:name]
    end

    def create
      Store.hset(@primary_key, @name, JSON.generate(self.as_json))
    end

    def update
      create()
    end

    def destroy
      Store.hdel(@primary_key, @name)
    end

    def as_json
      { 'name' => @name }
    end

    def as_config
      ""
    end

    def self.from_json(primary_key, json)
      json = JSON.parse(json) if String === json
      self.new(primary_key, **json)
    end

    def self.get(primary_key, name:)
      JSON.parse(Store.hget(primary_key, name))
    end

    def self.names(primary_key)
      Store.hkeys(primary_key)
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
  end
end
