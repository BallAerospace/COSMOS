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

require 'cosmos/utilities/logger'
require 'cosmos/config/config_parser'

module Cosmos
  class BridgeConfig
    # @return [Hash<String, Interface>] Interfaces hash
    attr_accessor :interfaces
    # @return [Hash<String, Interface>] Routers hash
    attr_accessor :routers

    def initialize(filename)
      @interfaces = {}
      @routers = {}
      process_file(filename)
    end

    def self.generate_default(filename)
      default_config =<<EOF
# Example Host Bridge Configuration for a Serial Port
#
# INTERFACE <Interface Name> <Interface File> <Interface Params...>
# INTERFACE <Interface Name> serial_interface.rb <Write Port> <Read Port> <Baud Rate> <Parity ODD/EVEN/NONE> <Stop Bits> <Write Timeout> <Read Timeout> <Protocol Name> <Protocol Params>
# INTERFACE <Interface Name> serial_interface.rb <Write Port> <Read Port> <Baud Rate> <Parity ODD/EVEN/NONE> <Stop Bits> <Write Timeout> <Read Timeout> BURST <Discard Leading Bytes> <Sync Pattern> <Add Sync On Write>
# INTERFACE SERIAL_INT serial_interface.rb /dev/ttyS1 /dev/ttyS1 38400 ODD 1 10.0 nil BURST 4 0xDEADBEEF
INTERFACE SERIAL_INT serial_interface.rb COM1 COM1 9600 NONE 1 10.0 nil BURST

# ROUTER <Router Name> <Interface File> <Interface Params...>
# ROUTER SERIAL_ROUTER tcpip_server_interface.rb <Write Port> <Read Port> <Write Timeout> <Read Timeout> <Protocol Name> <Protocol Params>
# ROUTER SERIAL_ROUTER tcpip_server_interface.rb <Write Port> <Read Port> <Write Timeout> <Read Timeout> BURST <Discard Leading Bytes> <Sync Pattern> <Add Sync On Write>
ROUTER SERIAL_ROUTER tcpip_server_interface.rb 2950 2950 10.0 nil BURST
  # ROUTE <Interface Name>
  ROUTE SERIAL_INT

EOF

      Logger.info "Writing #{filename}"
      File.open(filename, 'w') do |file|
        file.write(default_config)
      end
    end

    protected

    # Processes a file and adds in the configuration defined in the file
    #
    # @param filename [String] The name of the configuration file to parse
    # @param recursive [Boolean] Whether process_file is being called
    #   recursively
    def process_file(filename, recursive = false)
      current_interface_or_router = nil
      current_type = nil
      current_interface_log_added = false

      Logger.info "Processing Bridge configuration in file: #{File.expand_path(filename)}"

      Cosmos.set_working_dir do
        parser = ConfigParser.new
        parser.parse_file(filename) do |keyword, params|
          case keyword

          when 'INTERFACE'
            usage = "INTERFACE <Name> <Filename> <Specific Parameters>"
            parser.verify_num_parameters(2, nil, usage)
            interface_name = params[0].upcase
            raise parser.error("Interface '#{interface_name}' defined twice") if @interfaces[interface_name]
            interface_class = Cosmos.require_class(params[1])
            if params[2]
              current_interface_or_router = interface_class.new(*params[2..-1])
            else
              current_interface_or_router = interface_class.new
            end
            current_type = :INTERFACE
            current_interface_or_router.name = interface_name
            current_interface_or_router.config_params = params[1..-1]
            @interfaces[interface_name] = current_interface_or_router

          when 'RECONNECT_DELAY', 'LOG_RAW', 'OPTION', 'PROTOCOL'
            raise parser.error("No current interface or router for #{keyword}") unless current_interface_or_router

            case keyword

            when 'RECONNECT_DELAY'
              parser.verify_num_parameters(1, 1, "#{keyword} <Delay in Seconds>")
              current_interface_or_router.reconnect_delay = Float(params[0])

            when 'LOG_RAW',
              parser.verify_num_parameters(0, nil, "#{keyword} <Raw Logger Class File (optional)> <Raw Logger Parameters (optional)>")
              current_interface_or_router.raw_logger_pair = RawLoggerPair.new(current_interface_or_router.name, Dir.pwd, params)
              current_interface_or_router.start_raw_logging

            when 'OPTION'
              parser.verify_num_parameters(2, nil, "#{keyword} <Option Name> <Option Value 1> <Option Value 2 (optional)> <etc>")
              current_interface_or_router.set_option(params[0], params[1..-1])

            when 'PROTOCOL'
              usage = "#{keyword} <READ WRITE READ_WRITE> <protocol filename or classname> <Protocol specific parameters>"
              parser.verify_num_parameters(2, nil, usage)
              unless %w(READ WRITE READ_WRITE).include? params[0].upcase
                raise parser.error("Invalid protocol type: #{params[0]}", usage)
              end
              begin
                klass = Cosmos.require_class(params[1])
                current_interface_or_router.add_protocol(klass, params[2..-1], params[0].upcase.intern)
              rescue LoadError, StandardError => error
                raise parser.error(error.message, usage)
              end

            end # end case keyword for all keywords that require a current interface or router

          when 'ROUTER'
            usage = "ROUTER <Name> <Filename> <Specific Parameters>"
            parser.verify_num_parameters(2, nil, usage)
            router_name = params[0].upcase
            raise parser.error("Router '#{router_name}' defined twice") if @routers[router_name]
            router_class = Cosmos.require_class(params[1])
            if params[2]
             current_interface_or_router = router_class.new(*params[2..-1])
            else
             current_interface_or_router = router_class.new
            end
            current_type = :ROUTER
            current_interface_or_router.name = router_name
            @routers[router_name] = current_interface_or_router

          when 'ROUTE'
            raise parser.error("No current router for #{keyword}") unless current_interface_or_router and current_type == :ROUTER
            usage = "ROUTE <Interface Name>"
            parser.verify_num_parameters(1, 1, usage)
            interface_name = params[0].upcase
            interface = @interfaces[interface_name]
            raise parser.error("Unknown interface #{interface_name} mapped to router #{current_interface_or_router.name}") unless interface
            unless current_interface_or_router.interfaces.include? interface
              current_interface_or_router.interfaces << interface
              interface.routers << current_interface_or_router
            end

          else
            # blank lines will have a nil keyword and should not raise an exception
            raise parser.error("Unknown keyword: #{keyword}") unless keyword.nil?
          end  # case
        end  # loop
      end
    end
  end
end
