# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'openc3/utilities/store'
require 'openc3/config/config_parser'

module OpenC3
  class Model
    attr_accessor :name
    attr_accessor :updated_at
    attr_accessor :plugin
    attr_accessor :scope

    def self.store
      Store
    end

    # NOTE: The following three methods must be reimplemented by Model subclasses
    # without primary_key to support other class methods.

    # @return [Hash|nil] Hash of this model or nil if name not found under primary_key
    def self.get(primary_key, name:)
      json = store.hget(primary_key, name)
      if json
        return JSON.parse(json, :allow_nan => true, :create_additions => true)
      else
        return nil
      end
    end

    # @return [Array<String>] All the names stored under the primary key
    def self.names(primary_key)
      store.hkeys(primary_key).sort
    end

    # @return [Array<Hash>] All the models (as Hash objects) stored under the primary key
    def self.all(primary_key)
      hash = store.hgetall(primary_key)
      hash.each do |key, value|
        hash[key] = JSON.parse(value, :allow_nan => true, :create_additions => true)
      end
      hash
    end
    # END NOTE

    # Loops over all items and returns objects that match a key value pair
    def self.filter(key, value, scope:)
      filtered = {}
      results = all(scope: scope)
      results.each do |name, result|
        if result[key] == value
          filtered[name] = result
        end
      end
      return filtered
    end

    # Sets (updates) the redis hash of this model
    def self.set(json, scope:)
      json[:scope] = scope
      json.transform_keys!(&:to_sym)
      self.new(**json).create(force: true)
    end

    # @return [Model] Model generated from the passed JSON
    def self.from_json(json, scope:)
      json = JSON.parse(json, :allow_nan => true, :create_additions => true) if String === json
      raise "json data is nil" if json.nil?

      json[:scope] = scope
      json.transform_keys!(&:to_sym)
      self.new(**json, scope: scope)
    end

    # Calls self.get and then from_json to turn the Hash configuration into a Ruby Model object.
    # @return [Object|nil] Model object or nil if name not found under primary_key
    def self.get_model(name:, scope:)
      json = get(name: name, scope: scope)
      if json
        return from_json(json, scope: scope)
      else
        return nil
      end
    end

    # @return [Array<Object>] All the models (as Model objects) stored under the primary key
    def self.get_all_models(scope:)
      models = {}
      all(scope: scope).each { |name, json| models[name] = from_json(json, scope: scope) }
      models
    end

    # @return [Array<Object>] All the models (as Model objects) stored under the primary key
    #   which have the plugin attribute
    def self.find_all_by_plugin(plugin:, scope:)
      result = {}
      models = get_all_models(scope: scope)
      models.each do |name, model|
        result[name] = model if model.plugin == plugin
      end
      result
    end

    def self.handle_config(parser, model, keyword, parameters)
      raise "must be implemented by subclass"
    end

    # Store the primary key and keyword arguments
    def initialize(primary_key, **kw_args)
      @primary_key = primary_key
      @name = kw_args[:name]
      @updated_at = kw_args[:updated_at]
      @plugin = kw_args[:plugin]
      @scope = kw_args[:scope]
      @destroyed = false
    end

    # Update the Redis hash at primary_key and set the field "name"
    # to the JSON generated via calling as_json
    def create(update: false, force: false)
      unless force
        existing = self.class.store.hget(@primary_key, @name)
        if existing
          raise "#{@primary_key}:#{@name} already exists at create" unless update
        else
          raise "#{@primary_key}:#{@name} doesn't exist at update" if update
        end
      end
      @updated_at = Time.now.to_nsec_from_epoch
      self.class.store.hset(@primary_key, @name, JSON.generate(self.as_json(:allow_nan => true)))
    end

    # Alias for create(update: true)
    def update
      create(update: true)
    end

    # Deploy the model into the OpenC3 system. Subclasses must implement this
    # and typically create MicroserviceModels to implement.
    def deploy(gem_path, variables)
      raise "must be implemented by subclass"
    end

    # Undo the actions of deploy and remove the model from OpenC3.
    # Subclasses must implement this as by default it is a noop.
    def undeploy
    end

    # Delete the model from the Store
    def destroy
      @destroyed = true
      undeploy()
      self.class.store.hdel(@primary_key, @name)
    end

    # Indicate if destroy has been called
    def destroyed?
      @destroyed
    end

    # @return [Hash] JSON encoding of this model
    def as_json(*a)
      { 'name' => @name,
        'updated_at' => @updated_at,
        'plugin' => @plugin,
        'scope' => @scope }
    end

    # TODO: Not currently used but may be used by a XTCE or other format to OpenC3 conversion
    def as_config
      ""
    end
  end

  class EphemeralModel < Model
    def self.store
      EphemeralStore
    end
  end
end
