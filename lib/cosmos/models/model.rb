# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'cosmos/utilities/store'
require 'cosmos/config/config_parser'
require 'cosmos/utilities/authorization'

module Cosmos
  class Model
    include Authorization
    extend Authorization

    attr_accessor :name
    attr_accessor :updated_at
    attr_accessor :plugin
    attr_accessor :scope

    def initialize(primary_key, **kw_args)
      @primary_key = primary_key
      @name = kw_args[:name]
      @updated_at = kw_args[:updated_at]
      @plugin = kw_args[:plugin]
      @scope = kw_args[:scope]
    end

    def create(update: false, force: false)
      unless force
        existing = Store.hget(@primary_key, @name)
        if existing
          raise "#{@primary_key}:#{@name} already exists at create" unless update
        else
          raise "#{@primary_key}:#{@name} doesn't exist at update" if update
        end
      end
      @updated_at = Time.now.to_nsec_from_epoch
      Store.hset(@primary_key, @name, JSON.generate(self.as_json))
    end

    def update
      create(update: true)
    end

    def deploy(gem_path, variables)
      raise "must be implmented by subclass"
    end

    def undeploy
      # Does nothing by default
    end

    def destroy
      undeploy()
      Store.hdel(@primary_key, @name)
    end

    def as_json
      { 'name' => @name,
        'updated_at' => @updated_at,
        'plugin' => @plugin }
    end

    # TODO: This has a potential use-case in exporting other configuration formats
    # like XTCE back to COSMOS formats. However, it's currently not used.
    def as_config
      ""
    end

    def self.from_json(json, scope: nil)
      json = JSON.parse(json) if String === json
      raise "json data is nil" if json.nil?
      json[:scope] = scope
      json.transform_keys!(&:to_sym)
      self.new(**json, scope: scope)
    end

    def self.set(json, scope:)
      json[:scope] = scope
      json.transform_keys!(&:to_sym)
      self.new(**json).create(force: true)
    end

    def self.get(primary_key, name:)
      json = Store.hget(primary_key, name)
      if json
        return JSON.parse(json)
      else
        return nil
      end
    end

    # Note: This will only work in subclasses that reimplement get without primary_key
    def self.get_model(name:, scope:)
      json = get(name: name, scope: scope)
      if json
        return from_json(json, scope: scope)
      else
        return nil
      end
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

    # Note: This will only work in subclasses that reimplement all without primary_key
    def self.get_all_models(scope:)
      models = {}
      all(scope: scope).each { |name, json| models[name] = from_json(json, scope: scope) }
      models
    end

    # Note: This will only work in subclasses that reimplement all without primary_key
    def self.find_all_by_plugin(plugin:, scope:)
      result = {}
      models = get_all_models(scope: scope)
      models.each do |name, model|
        result[name] = model if model.plugin == plugin
      end
      result
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
