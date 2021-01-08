require 'cosmos/models/model'

module Cosmos
  class MicroserviceStatusModel < Model
    PRIMARY_KEY = 'cosmos_microservice_status'

    attr_accessor :state
    attr_accessor :count
    attr_accessor :error
    attr_accessor :custom

    def initialize(
      name:,
      state:,
      count: 0,
      error: nil,
      custom: nil,
      updated_at: nil,
      plugin: nil,
      scope:)
      super("#{scope}__#{PRIMARY_KEY}", name: name, updated_at: updated_at, plugin: plugin, scope: scope)
      @state = state
      @count = count
      @custom = custom
    end

    def as_json
      {
        'name' => @name,
        'state' => @state,
        'count' => @count,
        'error' => @error.as_json,
        'custom' => @custom.as_json,
        'plugin' => @plugin,
        'updated_at' => @updated_at
      }
    end

    def self.get(name:, scope:)
      super("#{scope}__#{PRIMARY_KEY}", name: name)
    end

    def self.names(scope:)
      super("#{scope}__#{PRIMARY_KEY}")
    end

    def self.all(scope:)
      super("#{scope}__#{PRIMARY_KEY}")
    end

  end
end