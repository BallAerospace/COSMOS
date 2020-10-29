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
      scope: nil)
      interface_or_router = self.class.name.to_s.split("Model")[0].upcase
      if interface_or_router == 'INTERFACE'
        super("#{scope}__#{INTERFACES_PRIMARY_KEY}", name: name)
      else
        super("#{scope}__#{ROUTERS_PRIMARY_KEY}", name: name)
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
        current_interface_or_router.add_protocol(klass, protocol[2..-1], protocol[0].upcase.intern)
      end
      interface_or_router.protocols = @protocols
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
        'interfaces' => @interfaces
      }
    end

    def as_config
      interface_or_router = self.class.name.to_s.split("Model")[0].upcase
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
      result
    end

    def self.handle_config(primary_key, parser, model, keyword, parameters)
      case keyword
      when 'INTERFACE', 'ROUTER'
        parser.verify_num_parameters(2, nil, "INTERFACE/ROUTER <Name> <Filename> <Specific Parameters>")
        return self.new(name: parameters[0].upcase, config_params: parameters[1..-1])

      when 'MAP_TARGET'
        parser.verify_num_parameters(1, 1, "#{keyword} <Target Name>")
        model.target_names << parameters[0].upcase

      when 'DONT_CONNECT'
        parser.verify_num_parameters(0, 0, "#{keyword}")
        model.connect_on_startup = false

      when 'DONT_RECONNECT'
        parser.verify_num_parameters(0, 0, "#{keyword}")
        model.auto_reconnect = false

      when 'RECONNECT_DELAY'
        parser.verify_num_parameters(1, 1, "#{keyword} <Delay in Seconds>")
        model.reconnect_delay = Float(parameters[0])

      when 'DISABLE_DISCONNECT'
        parser.verify_num_parameters(0, 0, "#{keyword}")
        model.disable_disconnect = true

      when 'OPTION'
        parser.verify_num_parameters(2, nil, "#{keyword} <Option Name> <Option Value 1> <Option Value 2 (optional)> <etc>")
        model.options << parameters.dup

      when 'PROTOCOL'
        usage = "#{keyword} <READ WRITE READ_WRITE> <protocol filename or classname> <Protocol specific parameters>"
        parser.verify_num_parameters(2, nil, usage)
        unless %w(READ WRITE READ_WRITE).include? parameters[0].upcase
          raise parser.error("Invalid protocol type: #{parameters[0]}", usage)
        end
        model.protocols << parameters.dup

      when 'ROUTE'
        parser.verify_num_parameters(1, 1, "ROUTE <Interface Name>")
        model.interfaces << parameters[0].upcase

      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Interface/Router: #{keyword} #{parameters.join(" ")}")

      end

      return nil
    end

    def self.from_json(json, scope: nil)
      json = JSON.parse(json) if String === json
      interface_or_router = self.name.to_s.split("Model")[0].upcase
      if interface_or_router == 'INTERFACE'
        self.new("#{scope}__#{INTERFACES_PRIMARY_KEY}", **json)
      else
        self.new("#{scope}__#{ROUTERS_PRIMARY_KEY}", **json)
      end
    end

    def self.get(name:, scope: nil, token: nil)
      interface_or_router = self.name.to_s.split("Model")[0].upcase
      if interface_or_router == 'INTERFACE'
        super("#{scope}__#{INTERFACES_PRIMARY_KEY}", name: name, scope: scope, token: token)
      else
        super("#{scope}__#{ROUTERS_PRIMARY_KEY}", name: name, scope: scope, token: token)
      end
    end

    def self.names(scope: nil, token: nil)
      interface_or_router = self.name.to_s.split("Model")[0].upcase
      if interface_or_router == 'INTERFACE'
        super("#{scope}__#{INTERFACES_PRIMARY_KEY}", scope: scope, token: token)
      else
        super("#{scope}__#{ROUTERS_PRIMARY_KEY}", scope: scope, token: token)
      end
    end

    def self.all(scope: nil, token: nil)
      interface_or_router = self.name.to_s.split("Model")[0].upcase
      if interface_or_router == 'INTERFACE'
        super("#{scope}__#{INTERFACES_PRIMARY_KEY}", scope: scope, token: token)
      else
        super("#{scope}__#{ROUTERS_PRIMARY_KEY}", scope: scope, token: token)
      end
    end
  end
end