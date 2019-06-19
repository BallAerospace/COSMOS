# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/config/config_parser'
require 'cosmos/interfaces'
require 'cosmos/tools/cmd_tlm_server/interface_thread'
require 'cosmos/packet_logs'
require 'cosmos/io/raw_logger_pair'

module Cosmos
  # Reads an ascii file that defines the configuration settings used to
  # configure the Command/Telemetry Server.
  class CmdTlmServerConfig
    # @return [Hash<String, Interface>] Interfaces hash
    attr_accessor :interfaces
    # @return [Hash<String, Interface>] Routers hash
    attr_accessor :routers
    # @return [Hash<String, PacketLogWriterPair>] Packet log writer hash. Each
    #   pair encapsulates a command and telemetry log writer.
    attr_accessor :packet_log_writer_pairs
    # @return [Array<BackgroundTask>] Array of background tasks
    attr_accessor :background_tasks
    # @return [String] Command and Telemetry Server title
    attr_accessor :title
    # @return [Boolean] Flag indicating if meta data should be collected
    attr_accessor :metadata

    # Create a default pair of packet log writers and parses the
    # configuration file.
    #
    # @param filename [String] The name of the configuration file to parse
    def initialize(filename)
      @interfaces = {}
      @routers = {}
      @packet_log_writer_pairs = {}
      cmd_log_writer = System.default_packet_log_writer.new(:CMD, *System.default_packet_log_writer_params)
      tlm_log_writer = System.default_packet_log_writer.new(:TLM, *System.default_packet_log_writer_params)
      @packet_log_writer_pairs['DEFAULT'] = PacketLogWriterPair.new(cmd_log_writer, tlm_log_writer)
      @background_tasks = []
      @title = nil
      @metadata = false
      process_file(filename)
    end

    protected

    def get_target_interface_name(target_name)
      @interfaces.each do |interface_name, interface|
        return interface_name if interface.target_names.include?(target_name)
      end
      nil
    end

    # Processes a file and adds in the configuration defined in the file
    #
    # @param filename [String] The name of the configuration file to parse
    # @param recursive [Boolean] Whether process_file is being called
    #   recursively
    def process_file(filename, recursive = false)
      current_interface_or_router = nil
      current_type = nil
      current_interface_log_added = false

      Logger.info "Processing CmdTlmServer configuration in file: #{File.expand_path(filename)}"

      Cosmos.set_working_dir do
        parser = ConfigParser.new("http://cosmosrb.com/docs/system/#command-and-telemetry-server-configuration")
        parser.parse_file(filename) do |keyword, params|
          case keyword
          when 'TITLE'
            raise parser.error("#{keyword} not allowed in target #{filename}") if recursive
            parser.verify_num_parameters(1, 1, "#{keyword} <Title Text>")
            @title = params[0]

          when 'PACKET_LOG_WRITER'
            usage = "PACKET_LOG_WRITER <Name> <Filename> <Specific Parameters>"
            parser.verify_num_parameters(2, nil, usage)
            packet_log_writer_name = params[0].upcase
            packet_log_writer_class = Cosmos.require_class(params[1])

            # Verify not overridding a packet log writer that is already associated with an interface
            packet_log_writer_pair = @packet_log_writer_pairs[packet_log_writer_name]
            if packet_log_writer_pair
              @interfaces.each do |interface_name, interface|
                if interface.packet_log_writer_pairs.include?(packet_log_writer_pair)
                  raise parser.error("Redefining Packet Log Writer #{packet_log_writer_name} not allowed after it is associated with an interface")
                end
              end
            end

            if params[2]
              cmd_log_writer = packet_log_writer_class.new(:CMD, *params[2..-1])
              tlm_log_writer = packet_log_writer_class.new(:TLM, *params[2..-1])
              @packet_log_writer_pairs[packet_log_writer_name] = PacketLogWriterPair.new(cmd_log_writer, tlm_log_writer)
            else
              cmd_log_writer = packet_log_writer_class.new(:CMD)
              tlm_log_writer = packet_log_writer_class.new(:TLM)
              @packet_log_writer_pairs[packet_log_writer_name] = PacketLogWriterPair.new(cmd_log_writer, tlm_log_writer)
            end

          when 'AUTO_INTERFACE_TARGETS'
            raise parser.error("#{keyword} not allowed in target #{filename}") if recursive
            usage = "#{keyword}"
            parser.verify_num_parameters(0, 0, usage)
            System.targets.each do |target_name, target|
              target_filename = File.join(target.dir, 'cmd_tlm_server.txt')
              if File.exist?(target_filename)
                # Skip this target if it's already been assigned an interface
                next if get_target_interface_name(target.name)
                raise parser.error("Cannot use #{keyword} with target name substitutions: #{target.name} != #{target.original_name}") if target.name != target.original_name
                process_file(target_filename, true)
              end
            end

          when 'INTERFACE_TARGET'
            raise parser.error("#{keyword} not allowed in target #{filename}") if recursive
            usage = "#{keyword} <Target Name> <Config File (defaults to cmd_tlm_server.txt)>"
            parser.verify_num_parameters(1, 2, usage)
            target = System.targets[params[0].upcase]
            raise parser.error("Unknown target: #{params[0].upcase}") unless target
            interface_name = get_target_interface_name(target.name)
            raise parser.error("Target #{target.name} already mapped to interface #{interface_name}") if interface_name
            target_filename = params[1]
            target_filename = 'cmd_tlm_server.txt' unless target_filename
            target_filename = File.join(target.dir, target_filename)
            if File.exist?(target_filename)
              process_file(target_filename, true)
            else
              raise parser.error("#{target_filename} does not exist")
            end

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
            current_interface_log_added = false
            current_interface_or_router.packet_log_writer_pairs << @packet_log_writer_pairs['DEFAULT']
            current_interface_or_router.name = interface_name
            @interfaces[interface_name] = current_interface_or_router

          when 'LOG', 'LOG_STORED', 'DONT_LOG', 'TARGET'
            raise parser.error("No current interface for #{keyword}") unless current_interface_or_router and current_type == :INTERFACE

            case keyword

            when 'LOG'
              parser.verify_num_parameters(1, 1, "#{keyword} <Packet Log Writer Name>")
              packet_log_writer_pair = @packet_log_writer_pairs[params[0].upcase]
              raise parser.error("Unknown packet log writer: #{params[0].upcase}") unless packet_log_writer_pair
              current_interface_or_router.packet_log_writer_pairs.delete(@packet_log_writer_pairs['DEFAULT']) unless current_interface_log_added
              current_interface_log_added = true
              current_interface_or_router.packet_log_writer_pairs << packet_log_writer_pair unless current_interface_or_router.packet_log_writer_pairs.include?(packet_log_writer_pair)

            when 'LOG_STORED'
              parser.verify_num_parameters(1, 1, "#{keyword} <Packet Log Writer Name>")
              packet_log_writer_pair = @packet_log_writer_pairs[params[0].upcase]
              raise parser.error("Unknown packet log writer: #{params[0].upcase}") unless packet_log_writer_pair
              current_interface_or_router.stored_packet_log_writer_pairs << packet_log_writer_pair unless current_interface_or_router.stored_packet_log_writer_pairs.include?(packet_log_writer_pair)

            when 'DONT_LOG'
              parser.verify_num_parameters(0, 0, "#{keyword}")
              current_interface_or_router.packet_log_writer_pairs = []

            when 'TARGET'
              parser.verify_num_parameters(1, 1, "#{keyword} <Target Name>")
              target_name = params[0].upcase
              target = System.targets[target_name]
              if target
                interface_name = get_target_interface_name(target.name)
                raise parser.error("Target #{target.name} already mapped to interface #{interface_name}") if interface_name
                target.interface = current_interface_or_router
                current_interface_or_router.target_names << target_name
              else
                raise parser.error("Unknown target #{target_name} mapped to interface #{current_interface_or_router.name}")
              end

            end # end case keyword for all keywords that require a current interface

          when 'DONT_CONNECT', 'DONT_RECONNECT', 'RECONNECT_DELAY', 'DISABLE_DISCONNECT', 'LOG_RAW', 'ROUTER_LOG_RAW', 'OPTION', 'PROTOCOL'
            raise parser.error("No current interface or router for #{keyword}") unless current_interface_or_router

            case keyword

            when 'DONT_CONNECT'
              parser.verify_num_parameters(0, 0, "#{keyword}")
              current_interface_or_router.connect_on_startup = false

            when 'DONT_RECONNECT'
              parser.verify_num_parameters(0, 0, "#{keyword}")
              current_interface_or_router.auto_reconnect = false

            when 'RECONNECT_DELAY'
              parser.verify_num_parameters(1, 1, "#{keyword} <Delay in Seconds>")
              current_interface_or_router.reconnect_delay = Float(params[0])

            when 'DISABLE_DISCONNECT'
              parser.verify_num_parameters(0, 0, "#{keyword}")
              current_interface_or_router.disable_disconnect = true

            # TODO: Deprecate ROUTER_LOG_RAW
            when 'LOG_RAW', 'ROUTER_LOG_RAW'
              parser.verify_num_parameters(0, nil, "#{keyword} <Raw Logger Class File (optional)> <Raw Logger Parameters (optional)>")
              current_interface_or_router.raw_logger_pair = RawLoggerPair.new(current_interface_or_router.name, params)
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

          when 'BACKGROUND_TASK'
            usage = "#{keyword} <Filename> <Specific Parameters>"
            parser.verify_num_parameters(1, nil, usage)
            background_task = Cosmos.require_class(params[0])
            if params[1]
              @background_tasks << background_task.new(*params[1..-1])
            else
              @background_tasks << background_task.new
            end

          when 'STOPPED'
            parser.verify_num_parameters(0, 0, "#{keyword}")
            raise parser.error("No BACKGROUND_TASK defined") if @background_tasks.empty?
            @background_tasks[-1].stopped = true

          when 'COLLECT_METADATA'
            parser.verify_num_parameters(0, 0, "#{keyword}")
            @metadata = true

          else
            # blank lines will have a nil keyword and should not raise an exception
            raise parser.error("Unknown keyword: #{keyword}") unless keyword.nil?
          end  # case
        end  # loop
      end
    end
  end
end
