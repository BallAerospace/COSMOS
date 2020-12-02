require 'cosmos/models/model'

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
      interfaces: [],
      log: true,
      log_raw: false,
      updated_at: nil,
      plugin: nil,
      scope:)
      interface_or_router = self.class.name.to_s.split("Model")[0].upcase.split("::")[-1]
      if interface_or_router == 'INTERFACE'
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
      @interfaces = interfaces
      @log = log
      @log_raw = log_raw
    end

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
      interface_or_router.interfaces = @interfaces
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
        'interfaces' => @interfaces,
        'log' => @log,
        'log_raw' => @log_raw,
        'plugin' => @plugin,
        'updated_at' => @updated_at
      }
    end

    def as_config
      interface_or_router = self.class.name.to_s.split("Model")[0].upcase.split("::")[-1]
      result = "#{interface_or_router} #{@name} #{@config_params.join(' ')}\n"
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
      @interfaces.each do |interface|
        result << "  ROUTE #{interface}\n"
      end
      result << "  DONT_LOG" unless @log
      result << "  LOG_RAW" if @log_raw
      result
    end

    def self.handle_config(parser, keyword, parameters, plugin: nil, scope:)
      case keyword
      when 'INTERFACE', 'ROUTER'
        parser.verify_num_parameters(2, nil, "INTERFACE/ROUTER <Name> <Filename> <Specific Parameters>")
        return self.new(name: parameters[0].upcase, config_params: parameters[1..-1], plugin: plugin, scope: scope)
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Interface/Router: #{keyword} #{parameters.join(" ")}")
      end
    end

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

      when 'ROUTE'
        parser.verify_num_parameters(1, 1, "ROUTE <Interface Name>")
        @interfaces << parameters[0].upcase

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

    def self.get(name:, scope: nil)
      interface_or_router = self.name.to_s.split("Model")[0].upcase.split("::")[-1]
      if interface_or_router == 'INTERFACE'
        super("#{scope}__#{INTERFACES_PRIMARY_KEY}", name: name)
      else
        super("#{scope}__#{ROUTERS_PRIMARY_KEY}", name: name)
      end
    end

    def self.names(scope: nil)
      interface_or_router = self.name.to_s.split("Model")[0].upcase.split("::")[-1]
      if interface_or_router == 'INTERFACE'
        result = super("#{scope}__#{INTERFACES_PRIMARY_KEY}")
        result
      else
        super("#{scope}__#{ROUTERS_PRIMARY_KEY}")
      end
    end

    def self.all(scope: nil)
      interface_or_router = self.name.to_s.split("Model")[0].upcase.split("::")[-1]
      if interface_or_router == 'INTERFACE'
        super("#{scope}__#{INTERFACES_PRIMARY_KEY}")
      else
        super("#{scope}__#{ROUTERS_PRIMARY_KEY}")
      end
    end

    def deploy(gem_path, variables)
      interface_or_router = self.class.name.to_s.split("Model")[0].upcase.split("::")[-1]

      if interface_or_router == 'INTERFACE'
        # Interface Microservice
        microservice_name = "#{@scope}__INTERFACE__#{@name}"
        microservice = MicroserviceModel.new(
          name: microservice_name,
          cmd: ["ruby", "interface_microservice.rb", microservice_name],
          work_dir: '/cosmos/lib/cosmos/microservices',
          target_names: @target_names,
          plugin: @plugin,
          scope: @scope)
        microservice.create
        microservice.deploy(gem_path, variables)
        Logger.info "Configured Interface Microservice #{microservice_name}"
      else
        # Router Microservice
        microservice_name = "#{@scope}__ROUTER__#{@name}"
        microservice = MicroserviceModel.new(
          name: microservice_name,
          cmd: ["ruby", "router_microservice.rb", microservice_name],
          work_dir: '/cosmos/lib/cosmos/microservices',
          target_names: @target_names,
          plugin: @plugin,
          scope: @scope)
        microservice.create
        microservice.deploy(gem_path, variables)
        Logger.info "Configured Router Microservice #{microservice_name}"
      end
    end

    def undeploy
      interface_or_router = self.class.name.to_s.split("Model")[0].upcase.split("::")[-1]

      if interface_or_router == 'INTERFACE'
        model = MicroserviceModel.get_model(name: "#{@scope}__INTERFACE__#{@name}", scope: @scope)
        model.destroy if model
      else
        model = MicroserviceModel.get_model(name: "#{@scope}__ROUTER__#{@name}", scope: @scope)
        model.destroy if model
      end
    end

  end
end