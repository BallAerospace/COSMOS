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

require 'cosmos/models/model'
require 'cosmos/models/microservice_model'

module Cosmos
  class InterfaceModel < Model
    INTERFACES_PRIMARY_KEY = 'cosmos_interfaces'
    ROUTERS_PRIMARY_KEY = 'cosmos_routers'

    attr_accessor :config_params
    attr_accessor :target_names
    attr_accessor :connect_on_startup
    attr_accessor :auto_reconnect
    attr_accessor :reconnect_delay
    attr_accessor :disable_disconnect
    attr_accessor :options
    attr_accessor :protocols
    attr_accessor :interfaces
    attr_accessor :log
    attr_accessor :log_raw

    # NOTE: The following three class methods are used by the ModelController
    # and are reimplemented to enable various Model class methods to work
    def self.get(name:, scope:)
      super("#{scope}__#{_get_key}", name: name)
    end

    def self.names(scope:)
      super("#{scope}__#{_get_key}")
    end

    def self.all(scope:)
      super("#{scope}__#{_get_key}")
    end
    # END NOTE

    # Called by the PluginModel to allow this class to validate it's top-level keyword: "INTERFACE"
    # Interface/Router specific keywords are handled by the instance method "handle_config"
    # NOTE: See RouterModel for the router method implementation
    def self.handle_config(parser, keyword, parameters, plugin: nil, scope:)
      case keyword
      when 'INTERFACE'
        parser.verify_num_parameters(2, nil, "INTERFACE <Name> <Filename> <Specific Parameters>")
        return self.new(name: parameters[0].upcase, config_params: parameters[1..-1], plugin: plugin, scope: scope)
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Interface: #{keyword} #{parameters.join(" ")}")
      end
    end

    # Helper method to return the correct type based on class name
    def self._get_type
      self.name.to_s.split("Model")[0].upcase.split("::")[-1]
    end

    # Helper method to return the correct primary key based on class name
    def self._get_key
      type = _get_type
      case type
      when 'INTERFACE'
        INTERFACES_PRIMARY_KEY
      when 'ROUTER'
        ROUTERS_PRIMARY_KEY
      else
        raise "Unknown type #{type} from class #{self.name}"
      end
    end

    def initialize(
      name:,
      config_params: [],
      target_names: [],
      connect_on_startup: true,
      auto_reconnect: true,
      reconnect_delay: 5.0,
      disable_disconnect: false,
      options: [],
      protocols: [],
      log: true,
      log_raw: false,
      updated_at: nil,
      plugin: nil,
      scope:)
      if self.class._get_type == 'INTERFACE'
        super("#{scope}__#{INTERFACES_PRIMARY_KEY}", name: name, updated_at: updated_at, plugin: plugin, scope: scope)
      else
        super("#{scope}__#{ROUTERS_PRIMARY_KEY}", name: name, updated_at: updated_at, plugin: plugin, scope: scope)
      end
      @config_params = config_params
      @target_names = target_names
      @connect_on_startup = connect_on_startup
      @auto_reconnect = auto_reconnect
      @reconnect_delay = reconnect_delay
      @disable_disconnect = disable_disconnect
      @options = options
      @protocols = protocols
      @log = log
      @log_raw = log_raw
    end

    # Called by InterfaceMicroservice to instantiate the Interface defined
    # by the model configuration. Must be called after get_model which
    # calls from_json to instantiate the class and populate the attributes.
    def build
      klass = Cosmos.require_class(@config_params[0])
      if @config_params.length > 1
        interface_or_router = klass.new(*@config_params[1..-1])
      else
        interface_or_router = klass.new
      end
      interface_or_router.target_names = @target_names.dup
      interface_or_router.connect_on_startup = @connect_on_startup
      interface_or_router.auto_reconnect = @auto_reconnect
      interface_or_router.reconnect_delay = @reconnect_delay
      interface_or_router.disable_disconnect = @disable_disconnect
      @options.each do |option|
        interface_or_router.set_option(option[0], option[1..-1])
      end
      @protocols.each do |protocol|
        klass = Cosmos.require_class(protocol[1])
        interface_or_router.add_protocol(klass, protocol[2..-1], protocol[0].upcase.intern)
      end
      interface_or_router
    end

    def as_json
      {
        'name' => @name,
        'config_params' => @config_params,
        'target_names' => @target_names,
        'connect_on_startup' => @connect_on_startup,
        'auto_reconnect' => @auto_reconnect,
        'reconnect_delay' => @reconnect_delay,
        'disable_disconnect' => @disable_disconnect,
        'options' => @options,
        'protocols' => @protocols,
        'log' => @log,
        'log_raw' => @log_raw,
        'plugin' => @plugin,
        'updated_at' => @updated_at
      }
    end

    # TODO: Not currently used but may be used by a XTCE or other format to COSMOS conversion
    def as_config
      result = "#{self.class._get_type} #{@name} #{@config_params.join(' ')}\n"
      @target_names.each do |target_name|
        result << "  MAP_TARGET #{target_name}\n"
      end
      result << "  DONT_CONNECT\n" unless @connect_on_startup
      result << "  DONT_RECONNECT\n" unless @auto_reconnect
      result << "  RECONNECT_DELAY #{@reconnect_delay}\n"
      result << "  DISABLE_DISCONNECT\n" if @disable_disconnect
      @options.each do |option|
        result << "  OPTION #{option.join(' ')}\n"
      end
      @protocols.each do |protocol|
        result << "  PROTOCOL #{protocol.join(' ')}\n"
      end
      result << "  DONT_LOG" unless @log
      result << "  LOG_RAW" if @log_raw
      result
    end

    # Handles Interface/Router specific configuration keywords
    def handle_config(parser, keyword, parameters)
      case keyword
      when 'MAP_TARGET'
        parser.verify_num_parameters(1, 1, "#{keyword} <Target Name>")
        @target_names << parameters[0].upcase

      when 'DONT_CONNECT'
        parser.verify_num_parameters(0, 0, "#{keyword}")
        @connect_on_startup = false

      when 'DONT_RECONNECT'
        parser.verify_num_parameters(0, 0, "#{keyword}")
        @auto_reconnect = false

      when 'RECONNECT_DELAY'
        parser.verify_num_parameters(1, 1, "#{keyword} <Delay in Seconds>")
        @reconnect_delay = Float(parameters[0])

      when 'DISABLE_DISCONNECT'
        parser.verify_num_parameters(0, 0, "#{keyword}")
        @disable_disconnect = true

      when 'OPTION'
        parser.verify_num_parameters(2, nil, "#{keyword} <Option Name> <Option Value 1> <Option Value 2 (optional)> <etc>")
        @options << parameters.dup

      when 'PROTOCOL'
        usage = "#{keyword} <READ WRITE READ_WRITE> <protocol filename or classname> <Protocol specific parameters>"
        parser.verify_num_parameters(2, nil, usage)
        unless %w(READ WRITE READ_WRITE).include? parameters[0].upcase
          raise parser.error("Invalid protocol type: #{parameters[0]}", usage)
        end
        @protocols << parameters.dup

      when 'DONT_LOG'
        parser.verify_num_parameters(0, 0, "#{keyword}")
        @log = false

      when 'LOG_RAW'
        parser.verify_num_parameters(0, 0, "#{keyword}")
        @log_raw = true

      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Interface/Router: #{keyword} #{parameters.join(" ")}")

      end

      return nil
    end

    # Creates a MicroserviceModel to deploy the Interface/Router
    def deploy(gem_path, variables)
      type = self.class._get_type
      microservice_name = "#{@scope}__#{type}__#{@name}"
      microservice = MicroserviceModel.new(
        name: microservice_name,
        work_dir: '/cosmos/lib/cosmos/microservices',
        cmd: ["ruby", "#{type.downcase}_microservice.rb", microservice_name],
        target_names: @target_names,
        plugin: @plugin,
        scope: @scope)
      microservice.create
      microservice.deploy(gem_path, variables)
      Logger.info "Configured #{type.downcase} microservice #{microservice_name}"
      microservice
    end

    # Looks up the deployed MicroserviceModel and destroys it
    def undeploy
      model = MicroserviceModel.get_model(name: "#{@scope}__#{self.class._get_type}__#{@name}", scope: @scope)
      model.destroy if model
    end
  end
end
