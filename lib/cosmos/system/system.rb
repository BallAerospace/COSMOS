# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/config/config_parser'
require 'cosmos/packets/packet_config'
require 'cosmos/packets/commands'
require 'cosmos/packets/telemetry'
require 'cosmos/packets/limits'
require 'cosmos/system/target'
require 'cosmos/packet_logs'
require 'fileutils'
require 'drb/acl'
require 'zip'
require 'zip/filesystem'
require 'bundler'
require 'thread'

module Cosmos
  # System is the primary entry point into the COSMOS framework. It captures
  # system wide configuration items such as the available ports and paths to
  # various files used by the system. The #commands, #telemetry, and #limits
  # class variables are the primary access points for applications. The
  # #targets variable provides access to all the targets defined by the system.
  # Its primary responsibily is to load the system configuration file and
  # create all the Target instances. It also saves and restores configurations
  # using a hashing checksum over the entire configuration to detect changes.
  class System
    # @return [Hash<String,Fixnum>] Hash of all the known ports and their values
    instance_attr_reader :ports
    # @return [Hash<String,String>] Hash of host names or ip addresses for tools to listen on
    instance_attr_reader :listen_hosts
    # @return [Hash<String,String>] Hash of host names or ip addresses for tools to connect to
    instance_attr_reader :connect_hosts
    # @return [Hash<String,String>] Hash of all the known paths and their values
    instance_attr_reader :paths
    # @return [PacketLogWriter] Class used to create log files
    instance_attr_reader :default_packet_log_writer
    # @return [Array<String>] Parameters to be used with the default log writer
    instance_attr_reader :default_packet_log_writer_params
    # @return [PacketLogReader] Class used to read log files
    instance_attr_reader :default_packet_log_reader
    # @return [Array<String>] Parameters to be used with the default log reader
    instance_attr_reader :default_packet_log_reader_params
    # @return [Boolean] Whether to use sound for alerts
    instance_attr_reader :sound
    # @return [Boolean] Whether to use DNS to lookup IP addresses or not
    instance_attr_reader :use_dns
    # @return [String] Stores the initial configuration file used when this
    #   System was initialized
    instance_attr_reader :initial_filename
    # @return [PacketConfig] Stores the initial packet list used when this
    #   System was initialized
    instance_attr_reader :initial_config
    # @return [ACL] Access control list showing which machines can have access
    instance_attr_reader :acl
    # @return [Hash<String,Target>] Hash of all the known targets
    instance_attr_reader :targets
    # @return [Integer] The number of seconds before a telemetry packet is considered stale
    instance_attr_reader :staleness_seconds
    # @return [Symbol] The current limits set
    instance_attr_reader :limits_set
    # @return [Boolean] Whether to use UTC or local times
    instance_attr_reader :use_utc
    # @return [Array<String>] List of files that are to be included in the hashing
    #   calculation in addition to the cmd/tlm definition files that are
    #   automatically included
    instance_attr_reader :additional_hashing_files
    # @return [Hash<String,String>] Hash of the text/color to use for the classificaiton banner
    instance_attr_reader :classificiation_banner
    # @return [String] Which hashing algorithm is in use
    instance_attr_reader :hashing_algorithm
    # @return [Boolean] Allow router commanding - defaults to false
    instance_attr_reader :allow_router_commanding
    # @return [String] API access secret using X-Csrf-Token - defaults to SuperSecret
    instance_attr_reader :x_csrf_token
    # @return [Array<String>] Allowed origins in http origin header - defaults to no origin header only
    instance_attr_reader :allowed_origins
    # @return [Array<String>] Allowed hosts in http host header - defaults to '127.0.0.1:7777' only
    instance_attr_reader :allowed_hosts

    # Known COSMOS ports
    KNOWN_PORTS = ['CTS_API', 'TLMVIEWER_API', 'CTS_PREIDENTIFIED', 'CTS_CMD_ROUTER', 'REPLAY_API', 'REPLAY_PREIDENTIFIED', 'REPLAY_CMD_ROUTER', 'DART_STREAM', 'DART_DECOM', 'DART_MASTER']
    API_PORTS = ['CTS_API', 'TLMVIEWER_API', 'REPLAY_API', 'DART_DECOM', 'DART_MASTER']
    # Known COSMOS hosts
    KNOWN_HOSTS = ['CTS_API', 'TLMVIEWER_API', 'CTS_PREIDENTIFIED', 'CTS_CMD_ROUTER', 'REPLAY_API', 'REPLAY_PREIDENTIFIED', 'REPLAY_CMD_ROUTER', 'DART_STREAM', 'DART_DECOM', 'DART_MASTER']
    # Known COSMOS paths
    KNOWN_PATHS = ['LOGS', 'TMP', 'SAVED_CONFIG', 'TABLES', 'HANDBOOKS', 'PROCEDURES', 'SEQUENCES', 'DART_DATA', 'DART_LOGS']
    # Supported hashing algorithms
    SUPPORTED_HASHING_ALGORITHMS = ['MD5', 'RMD160', 'SHA1', 'SHA256', 'SHA384', 'SHA512']

    @@instance = nil
    @@instance_mutex = Mutex.new
    @@instance_filename = nil

    # Create a new System object. Note, this should not be called directly but
    # you should instead use System.instance and treat this class as a
    # singleton.
    #
    # @param filename [String] Full path to the system configuration file to
    #   read. Be default this is <Cosmos::USERPATH>/config/system/system.txt
    def initialize(filename = nil)
      raise "Cosmos::System created twice" unless @@instance.nil?
      @@instance_filename = filename
      reset_variables(filename)
      @@instance = self
    end

    # @return [String] Configuration name
    def self.configuration_name
      # In order not to make the @config instance variable accessable to the
      # outside (using a regular accessor method) we use the ability of the
      # object to grab its own instance variable
      self.instance.instance_variable_get(:@config).name
    end

    # Clear the command and telemetry counters for all the targets as well as
    # the counters associated with the Commands and Telemetry instances
    def self.clear_counters
      self.instance.targets.each do |target_name, target|
        target.cmd_cnt = 0
        target.tlm_cnt = 0
      end
      self.instance.telemetry.clear_counters
      self.instance.commands.clear_counters
    end

    # @return [Commands] Access to the command definiton
    def commands
      load_packets() unless @config
      return @commands
    end

    # (see #commands)
    def self.commands
      return self.instance.commands
    end

    # @return [Telemetry] Access to the telemetry definition
    def telemetry
      load_packets() unless @config
      return @telemetry
    end

    # (see #telemetry)
    def self.telemetry
      return self.instance.telemetry
    end

    # @return [Limits] Access to the limits definition
    def limits
      load_packets() unless @config
      return @limits
    end

    # (see #limits)
    def self.limits
      return self.instance.limits
    end

    # Change the system limits set
    #
    # @param limits_set [Symbol] The name of the limits set. :DEFAULT is always an option
    #   but limits sets are user defined
    def limits_set=(limits_set)
      load_packets() unless @config
      new_limits_set = limits_set.to_s.upcase.intern
      if @limits_set != new_limits_set
        if @config.limits_sets.include?(new_limits_set)
          @limits_set = new_limits_set
          Logger.info("Limits Set Changed to: #{@limits_set}")
          CmdTlmServer.instance.post_limits_event(:LIMITS_SET, System.limits_set) if defined? CmdTlmServer && CmdTlmServer.instance
        else
          raise "Unknown limits set requested: #{new_limits_set}"
        end
      end
    end

    # (see #limits_set=)
    def self.limits_set=(limits_set)
      self.instance.limits_set = limits_set
    end

    # @param filename [String] System configuration file to parse
    # @return [System] The System singleton
    def self.instance(filename = nil)
      return @@instance if @@instance
      @@instance_mutex.synchronize do
        @@instance ||= self.new(filename)
        return @@instance
      end
    end

    # Process the system.txt configuration file
    #
    # @param filename [String] The configuration file
    # @param configuration_directory [String] The configuration directory to
    #   search for the target command and telemetry files. Pass nil to look in
    #   the default location of <USERPATH>/config/targets.
    def process_file(filename, configuration_directory = nil)
      @targets = {}
      # Set config to nil so things will lazy load later
      @config = nil
      @meta_init_filename = nil
      @use_utc = false
      acl_list = []
      all_allowed = false
      first_procedures_path = true
      @additional_hashing_files = []

      Cosmos.set_working_dir do
        parser = ConfigParser.new("https://ballaerospace.github.io/cosmos-website/docs/v4/system")

        # First pass - Everything except targets
        parser.parse_file(filename) do |keyword, parameters|
          case keyword
          when 'AUTO_DECLARE_TARGETS', 'DECLARE_TARGET', 'DECLARE_GEM_TARGET', 'DECLARE_GEM_MULTI_TARGET'
            # Will be handled by second pass

          when 'PORT'
            usage = "#{keyword} <PORT NAME> <PORT VALUE>"
            parser.verify_num_parameters(2, 2, usage)
            port_name = parameters[0].to_s.upcase
            @ports[port_name] = Integer(parameters[1])
            @allowed_hosts << "127.0.0.1:#{parameters[1]}" if API_PORTS.include?(port_name)
            Logger.warn("Unknown port name given: #{port_name}") unless KNOWN_PORTS.include?(port_name)

          when 'LISTEN_HOST', 'CONNECT_HOST'
            usage = "#{keyword} <HOST NAME> <HOST VALUE>"
            parser.verify_num_parameters(2, 2, usage)
            host_name = parameters[0].to_s.upcase
            host = parameters[1]
            host = '127.0.0.1' if host.to_s.upcase == 'LOCALHOST'
            if keyword == 'LISTEN_HOST'
              @listen_hosts[host_name] = host
            else
              @connect_hosts[host_name] = host
            end
            Logger.warn("Unknown host name given: #{host_name}") unless KNOWN_HOSTS.include?(host_name)

          when 'PATH'
            usage = "#{keyword} <PATH NAME> <PATH>"
            parser.verify_num_parameters(2, 2, usage)
            path_name = parameters[0].to_s.upcase
            path = File.expand_path(parameters[1])
            if path_name == 'PROCEDURES'
              if first_procedures_path
                @paths[path_name] = []
                first_procedures_path = false
              end
              @paths[path_name] << path
            else
              @paths[path_name] = path
            end
            unless Dir.exist?(path)
              begin
                FileUtils.mkdir_p(path)
                raise "Path creation failed: #{path}" unless File.exist?(path)
                Logger.info "Created PATH #{path_name} #{path}"
              rescue Exception => err
                Logger.error "Problem creating PATH #{path_name} #{path}\n#{err.formatted}"
              end
            end
            Logger.warn("Unknown path name given: #{path_name}") unless KNOWN_PATHS.include?(path_name)

          when 'DEFAULT_PACKET_LOG_WRITER'
            usage = "#{keyword} <FILENAME> <Specific Parameters>"
            parser.verify_num_parameters(1, nil, usage)
            Cosmos.disable_warnings do
              @default_packet_log_writer = Cosmos.require_class(parameters[0])
            end
            @default_packet_log_writer_params = parameters[1..-1] if parameters.size > 1

          when 'DEFAULT_PACKET_LOG_READER'
            usage = "#{keyword} <FILENAME> <Specific Parameters>"
            parser.verify_num_parameters(1, nil, usage)
            Cosmos.disable_warnings do
              @default_packet_log_reader = Cosmos.require_class(parameters[0])
            end
            @default_packet_log_reader_params = parameters[1..-1] if parameters.size > 1

          when 'ENABLE_SOUND'
            usage = "#{keyword}"
            parser.verify_num_parameters(0, 0, usage)
            @sound = true

          when 'DISABLE_DNS'
            usage = "#{keyword}"
            parser.verify_num_parameters(0, 0, usage)
            @use_dns = false

          when 'ENABLE_DNS'
            usage = "#{keyword}"
            parser.verify_num_parameters(0, 0, usage)
            @use_dns = true

          when 'ALLOW_ACCESS'
            parser.verify_num_parameters(1, 1, "#{keyword} <IP Address or Hostname>")
            begin
              addr = parameters[0].upcase
              if addr == 'ALL'
                all_allowed = true
                acl_list = []
              end

              unless all_allowed
                first_char = addr[0..0]
                if !((first_char =~ /[1234567890]/) || (first_char == '*') || (addr.upcase == 'ALL'))
                  # Try to lookup IP Address
                  info = Socket.gethostbyname(addr)
                  addr = "#{info[3].getbyte(0)}.#{info[3].getbyte(1)}.#{info[3].getbyte(2)}.#{info[3].getbyte(3)}"
                  if (acl_list.empty?)
                    acl_list << 'allow'
                    acl_list << '127.0.0.1'
                  end
                  acl_list << 'allow'
                  acl_list << addr
                else
                  raise "badly formatted address #{addr}" unless /\b(?:\d{1,3}\.){3}\d{1,3}\b/.match(addr)
                  if (acl_list.empty?)
                    acl_list << 'allow'
                    acl_list << '127.0.0.1'
                  end
                  acl_list << 'allow'
                  acl_list << addr
                end
              end
            rescue => err
              raise parser.error("Problem with ALLOW_ACCESS due to #{err.message.strip}")
            end

          when 'STALENESS_SECONDS'
            parser.verify_num_parameters(1, 1, "#{keyword} <Value in Seconds>")
            @staleness_seconds = Integer(parameters[0])

          when 'META_INIT'
            parser.verify_num_parameters(1, 1, "#{keyword} <Filename>")
            @meta_init_filename = ConfigParser.handle_nil(parameters[0])

          when 'TIME_ZONE_UTC'
            parser.verify_num_parameters(0, 0, "#{keyword}")
            @use_utc = true

          when 'ADD_HASH_FILE', 'ADD_MD5_FILE' # MD5 is here for backwards compatibility
            parser.verify_num_parameters(1, 1, "#{keyword} <Filename>")
            if File.file?(parameters[0])
              @additional_hashing_files << File.expand_path(parameters[0])
            elsif File.file?(File.join(Cosmos::USERPATH, parameters[0]))
              @additional_hashing_files << File.expand_path(File.join(Cosmos::USERPATH, parameters[0]))
            else
              raise "Missing expected file: #{parameters[0]}"
            end

          when 'HASHING_ALGORITHM'
            parser.verify_num_parameters(1, 1, "#{keyword} <Hashing Algorithm>")
            if SUPPORTED_HASHING_ALGORITHMS.include? parameters[0]
              @hashing_algorithm = parameters[0]
            else
              Logger.error "Unrecognized hashing algorithm: #{parameters[0]}, using default algorithm MD5"
              @hashing_algorithm = 'MD5'
            end

          when 'CLASSIFICATION'
            parser.verify_num_parameters(2, 4, "#{keyword} <Display_Text> <Color Name|Red> <Green> <Blue>")
            # Determine if the COSMOS color already exists, otherwise create a new one
            if Cosmos.constants.include? parameters[1].upcase.to_sym
              # We were given a named color that already exists in COSMOS
              color = eval("Cosmos::#{parameters[1].upcase}")
            else
              if parameters.length < 4
                # We were given a named color, but it didn't exist in COSMOS already
                color = Cosmos::getColor(parameters[1].upcase)
              else
                # We were given RGB values
                color = Cosmos::getColor(parameters[1], parameters[2], parameters[3])
              end
            end

            @classificiation_banner = {'display_text' => parameters[0],
                                       'color'        => color}

          when 'ALLOW_ROUTER_COMMANDING'
            parser.verify_num_parameters(0, 0, "#{keyword}")
            @allow_router_commanding = true

          when 'X_CSRF_TOKEN'
            parser.verify_num_parameters(1, 1, "#{keyword} <Token>")
            @x_csrf_token = ConfigParser.handle_nil(parameters[0])

          when 'ALLOW_ORIGIN'
            parser.verify_num_parameters(1, 1, "#{keyword} <Origin>")
            @allowed_origins << parameters[0]

          when 'ALLOW_HOST'
            parser.verify_num_parameters(1, 1, "#{keyword} <Host:Port>")
            @allowed_hosts << parameters[0]

          else
            # blank lines will have a nil keyword and should not raise an exception
            raise parser.error("Unknown keyword '#{keyword}'") if keyword
          end # case keyword
        end # parser.parse_file

        @acl = ACL.new(acl_list, ACL::ALLOW_DENY) unless acl_list.empty?

        # Explicitly set up time to use UTC or local
        if @use_utc
          Time.use_utc()
        else
          Time.use_local()
        end

        # Second pass - Process targets
        process_targets(parser, filename, configuration_directory)

      end # Cosmos.set_working_dir
    end # def process_file

    # Parse the system.txt configuration file looking for keywords associated
    # with targets and create all the Target instances in the system.
    #
    # @param parser [ConfigParser] Parser created by process_file
    # @param filename (see #process_file)
    # @param configuration_directory (see #process_file)
    def process_targets(parser, filename, configuration_directory)
      parser.parse_file(filename) do |keyword, parameters|
        case keyword
        when 'AUTO_DECLARE_TARGETS'
          usage = "#{keyword}"
          parser.verify_num_parameters(0, 0, usage)
          path = File.join(USERPATH, 'config', 'targets')
          unless File.exist? path
            raise parser.error("#{path} must exist", usage)
          end
          dirs = []
          Dir.foreach(File.join(USERPATH, 'config', 'targets')) { |dir_filename| dirs << dir_filename }
          dirs.sort!
          dirs.each do |dir_filename|
            if dir_filename[0] != '.'
              if dir_filename == dir_filename.upcase
                # If any of the targets original directory name matches the
                # current directory then it must have been already processed by
                # DECLARE_TARGET so we skip it.
                next if @targets.select {|name, target| target.original_name == dir_filename }.length > 0
                next if dir_filename == 'SYSTEM'
                target = Target.new(dir_filename)
                @targets[target.name] = target
              else
                raise parser.error("Target folder must be uppercase: '#{dir_filename}'")
              end
            end
          end
          auto_detect_gem_based_targets()

        when 'DECLARE_TARGET'
          usage = "#{keyword} <TARGET NAME> <SUBSTITUTE TARGET NAME (Optional)> <TARGET FILENAME (Optional - defaults to target.txt)>"
          parser.verify_num_parameters(1, 3, usage)
          target_name = parameters[0].to_s.upcase
          substitute_name = nil
          substitute_name = ConfigParser.handle_nil(parameters[1])
          substitute_name.to_s.upcase if substitute_name
          if configuration_directory
            folder_name = File.join(configuration_directory, target_name)
          else
            folder_name = File.join(USERPATH, 'config', 'targets', target_name)
          end
          unless Dir.exist?(folder_name)
            raise parser.error("Target folder must exist '#{folder_name}'.")
          end
          target = Target.new(target_name, substitute_name, configuration_directory, ConfigParser.handle_nil(parameters[2]))
          @targets[target.name] = target

        when 'DECLARE_GEM_TARGET'
          usage = "#{keyword} <GEM NAME> <SUBSTITUTE TARGET NAME (Optional)> <TARGET FILENAME (Optional - defaults to target.txt)>"
          parser.verify_num_parameters(1, 3, usage)
          # Remove 'cosmos' from the gem name 'cosmos-power-supply'
          target_name = parameters[0].split('-')[1..-1].join('-').to_s.upcase
          substitute_name = nil
          substitute_name = ConfigParser.handle_nil(parameters[1])
          substitute_name.to_s.upcase if substitute_name
          gem_dir = Gem::Specification.find_by_name(parameters[0]).gem_dir
          target = Target.new(target_name, substitute_name, configuration_directory, ConfigParser.handle_nil(parameters[2]), gem_dir)
          @targets[target.name] = target

        when 'DECLARE_GEM_MULTI_TARGET'
          usage = "#{keyword} <GEM NAME> <TARGET NAME> <SUBSTITUTE TARGET NAME (Optional)> <TARGET FILENAME (Optional - defaults to target.txt)>"
          parser.verify_num_parameters(2, 4, usage)

          target_name = parameters[1].to_s.upcase
          substitute_name = nil
          substitute_name = ConfigParser.handle_nil(parameters[2])
          substitute_name.to_s.upcase if substitute_name
          gem_dir = Gem::Specification.find_by_name(parameters[0]).gem_dir
          gem_dir = File.join(gem_dir, target_name)
          target = Target.new(target_name, substitute_name, configuration_directory, ConfigParser.handle_nil(parameters[3]), gem_dir)
          @targets[target.name] = target

        end # case keyword
      end # parser.parse_file

      # Make sure SYSTEM target is always present and added last
      unless @targets.key?('SYSTEM')
        target = Target.new('SYSTEM')
        @targets[target.name] = target
      end
    end

    # Load the specified configuration by iterating through the SAVED_CONFIG
    # directory looking for a matching hashing sum. Updates the internal state so
    # subsequent commands and telemetry methods return the new configuration.
    #
    # @param name [String] hash string which identifies the
    #   configuration. Pass nil to load the default configuration.
    # @return [String, Exception/nil] The actual configuration loaded
    def load_configuration(name = nil)
      # Ensure packets have been lazy loaded
      load_packets() unless @config

      @@instance_mutex.synchronize do
        if @config_blacklist[name]
          Logger.warn "Ignoring failed config #{name}"
          update_config(@initial_config)
          return @config.name, RuntimeError.new("Ignoring failed config #{name}")
        end

        if name && @config
          # Make sure they're requesting something other than the current
          # configuration.
          if name != @config.name
            # If they want the initial configuration we can just swap out the
            # current configuration without doing any file processing
            if name == @initial_config.name
              Logger.info "Switching to initial configuration: #{name}"
              update_config(@initial_config)
            else
              # Look for the requested configuration in the saved configurations
              configuration = find_configuration(name)
              if configuration
                # We found the configuration requested. Reprocess the system.txt
                # and reload the packets
                begin
                  unless File.directory?(configuration)
                    # Zip file configuration so unzip and reset configuration path
                    configuration = unzip(configuration)
                  end

                  Logger.info "Switching to configuration: #{name}"
                  process_file(File.join(configuration, 'system.txt'), configuration)
                  load_packets(name, false)
                rescue Exception => error
                  # Failed to load - Restore initial
                  @config_blacklist[name] = true # Prevent wasting time trying to load the bad configuration again
                  Logger.error "Problem loading configuration from #{configuration}: #{error.class}:#{error.message}\n#{error.backtrace.join("\n")}\n"
                  Logger.info "Switching to initial configuration: #{@initial_config.name}"
                  update_config(@initial_config)
                  return @config.name, error
                end
              else
                # We couldn't find the configuration request. Reload the
                # initial configuration
                Logger.error "Unable to find configuration: #{name}"
                Logger.info "Switching to initial configuration: #{@initial_config.name}"
                update_config(@initial_config)
                return @config.name, RuntimeError.new("Unable to find configuration: #{name}")
              end
            end
          end
        else
          Logger.info "Switching to initial configuration: #{@initial_config.name}"
          update_config(@initial_config)
        end

        return @config.name, nil
      end
    end

    # (see #load_configuration)
    def self.load_configuration(name = nil)
      return self.instance.load_configuration(name)
    end

    # Resets the System's internal state to defaults.
    #
    # @param filename [String] Path to system.txt config file to process. Defaults to config/system/system.txt
    def reset_variables(filename = nil)
      @targets = {}
      @config = nil
      @commands = nil
      @telemetry = nil
      @limits = nil
      @default_packet_log_writer = PacketLogWriter
      @default_packet_log_writer_params = []
      @default_packet_log_reader = PacketLogReader
      @default_packet_log_reader_params = []
      @sound = false
      @use_dns = false
      @acl = nil
      @staleness_seconds = 30
      @limits_set = :DEFAULT
      @use_utc = false
      @additional_hashing_files = []
      @meta_init_filename = nil
      @hashing_algorithm = 'MD5'

      @ports = {}
      @ports['CTS_API'] = 7777
      @ports['TLMVIEWER_API'] = 7778
      @ports['CTS_PREIDENTIFIED'] = 7779
      @ports['CTS_CMD_ROUTER'] = 7780
      @ports['REPLAY_API'] = 7877
      @ports['REPLAY_PREIDENTIFIED'] = 7879
      @ports['REPLAY_CMD_ROUTER'] = 7880

      @ports['DART_STREAM'] = 8777
      @ports['DART_DECOM'] = 8779
      @ports['DART_MASTER'] = 8780

      @listen_hosts = {}
      @listen_hosts['CTS_API'] = '127.0.0.1'
      @listen_hosts['TLMVIEWER_API'] = '127.0.0.1'
      @listen_hosts['CTS_PREIDENTIFIED'] = '127.0.0.1'
      @listen_hosts['CTS_CMD_ROUTER'] = '127.0.0.1'
      @listen_hosts['REPLAY_API'] = '127.0.0.1'
      @listen_hosts['REPLAY_PREIDENTIFIED'] = '127.0.0.1'
      @listen_hosts['REPLAY_CMD_ROUTER'] = '127.0.0.1'
      @listen_hosts['DART_STREAM'] = '127.0.0.1'
      @listen_hosts['DART_DECOM'] = '127.0.0.1'
      @listen_hosts['DART_MASTER'] = '127.0.0.1'

      @connect_hosts = {}
      @connect_hosts['CTS_API'] = '127.0.0.1'
      @connect_hosts['TLMVIEWER_API'] = '127.0.0.1'
      @connect_hosts['CTS_PREIDENTIFIED'] = '127.0.0.1'
      @connect_hosts['CTS_CMD_ROUTER'] = '127.0.0.1'
      @connect_hosts['REPLAY_API'] = '127.0.0.1'
      @connect_hosts['REPLAY_PREIDENTIFIED'] = '127.0.0.1'
      @connect_hosts['REPLAY_CMD_ROUTER'] = '127.0.0.1'
      @connect_hosts['DART_STREAM'] = '127.0.0.1'
      @connect_hosts['DART_DECOM'] = '127.0.0.1'
      @connect_hosts['DART_MASTER'] = '127.0.0.1'

      @paths = {}
      @paths['LOGS'] = File.join(USERPATH, 'outputs', 'logs')
      @paths['TMP'] = File.join(USERPATH, 'outputs', 'tmp')
      @paths['SAVED_CONFIG'] = File.join(USERPATH, 'outputs', 'saved_config')
      @paths['TABLES'] = File.join(USERPATH, 'outputs', 'tables')
      @paths['HANDBOOKS'] = File.join(USERPATH, 'outputs', 'handbooks')
      @paths['PROCEDURES'] = [File.join(USERPATH, 'procedures')]
      @paths['SEQUENCES'] = File.join(USERPATH, 'outputs', 'sequences')
      @paths['DART_DATA'] = File.join(USERPATH, 'outputs', 'dart', 'data')
      @paths['DART_LOGS'] = File.join(USERPATH, 'outputs', 'dart', 'logs')

      @allow_router_commanding = false
      @x_csrf_token = 'SuperSecret'
      @allowed_origins = []
      @allowed_hosts = ['127.0.0.1:7777', '127.0.0.1:7778', '127.0.0.1:7877', '127.0.0.1:8779', '127.0.0.1:8780']

      unless filename
        system_arg = false
        ARGV.each do |arg|
          if system_arg
            filename = File.join(USERPATH, 'config', 'system', arg)
            break
          end
          system_arg = true if arg == '--system'
        end
        filename = File.join(USERPATH, 'config', 'system', 'system.txt') unless filename
      end
      process_file(filename)
      ENV['COSMOS_LOGS_DIR'] = @paths['LOGS']

      @initial_filename = filename
      @initial_config = nil
      @config_blacklist = {}
    end

    # Reset variables and load packets
    def reset(filename = @@instance_filename)
      reset_variables(filename)
      load_packets()
    end

    # Class level convenience reset method
    def self.reset
      self.instance.reset
    end

    def find_configuration(name)
      Cosmos.set_working_dir do
        Dir.foreach(@paths['SAVED_CONFIG']) do |filename|
          full_path = File.join(@paths['SAVED_CONFIG'], filename)
          if File.exist?(full_path) && File.basename(filename, ".*")[-32..-1] == name
            return full_path
          end
        end
      end
      nil
    end

    protected

    def unzip(zip_file_name)
      zip_dir = File.join(@paths['TMP'], File.basename(zip_file_name, ".*"))
      # Only unzip if we have to. We assume the unzipped directory structure is
      # intact. If not they'll get a popop with the errors encountered when
      # loading the configuration.
      unless File.exist? zip_dir
        Zip::File.open(zip_file_name) do |zip_file|
          zip_file.each do |entry|
            path = File.join(@paths['TMP'], entry.name)
            FileUtils.mkdir_p(File.dirname(path))
            zip_file.extract(entry, path) unless File.exist?(path)
          end
        end
      end
      zip_dir
    end

    # A helper method to make the zip writing recursion work
    def write_zip_entries(base_dir, entries, zip_path, io)
      io.add(zip_path, base_dir) # Add the directory whether it has entries or not
      entries.each do |e|
        zip_file_path = File.join(zip_path, e)
        disk_file_path = File.join(base_dir, e)
        if File.directory? disk_file_path
          recursively_deflate_directory(disk_file_path, io, zip_file_path)
        else
          put_into_archive(disk_file_path, io, zip_file_path)
        end
      end
    end

    def recursively_deflate_directory(disk_file_path, io, zip_file_path)
      io.add(zip_file_path, disk_file_path)
      entries = Dir.entries(disk_file_path) - %w(. ..)
      write_zip_entries(disk_file_path, entries, zip_file_path, io)
    end

    def put_into_archive(disk_file_path, io, zip_file_path)
      io.get_output_stream(zip_file_path) do |f|
        data = nil
        File.open(disk_file_path, 'rb') do |file|
          data = file.read
        end
        f.write(data)
      end
    end

    def auto_detect_gem_based_targets
      Bundler.load.specs.each do |spec|
        spec_name_split = spec.name.split('-')
        if spec_name_split.length > 1 && (spec_name_split[0] == 'cosmos')
          # search for multiple targets packaged in a single gem
          dirs = []
          Dir.foreach(spec.gem_dir) { |dir_filename| dirs << dir_filename }
          dirs.sort!
          dirs.each do |dir_filename|
            if dir_filename == "."
              # check the base directory
              curr_dir = spec.gem_dir
              target_name = spec_name_split[1..-1].join('-').to_s.upcase
            else
              #check for targets in other directories 1 level deep
              next if dir_filename[0] == '.'               #skip dot directories and ".."
              next if dir_filename != dir_filename.upcase  #skip non uppercase directories
              curr_dir = File.join(spec.gem_dir, dir_filename)
              target_name = dir_filename
            end
            # check for the cmd_tlm directory - if it has it, then we have found a target
            if File.directory?(File.join(curr_dir,'cmd_tlm'))
              # If any of the targets original directory name matches the
              # current directory then it must have been already processed by
              # DECLARE_TARGET so we skip it.
              next if @targets.select {|name, target| target.original_name == target_name }.length > 0
              target = Target.new(target_name,nil, nil, nil, spec.gem_dir)
              @targets[target.name] = target
           end
          end
        end
      end
    rescue Bundler::GemfileNotFound
      # No Gemfile - so no gem based targets
    end

    def update_config(config)
      current_config = @config
      unless @config
        @config = config
        @commands  = Commands.new(config)
        @telemetry = Telemetry.new(config)
        @limits = Limits.new(config)
      else
        @config = config
        @commands.config = config
        @telemetry.config = config
        @limits.config = config
      end
      @telemetry.reset if current_config != config
    end

    def save_configuration
      Cosmos.set_working_dir do
        configuration = find_configuration(@config.name)
        configuration = File.join(@paths['SAVED_CONFIG'], File.build_timestamped_filename([@config.name], '.zip')) unless configuration
        unless File.exist?(configuration)
          configuration_tmp = File.join(@paths['SAVED_CONFIG'], File.build_timestamped_filename(['tmp_' + @config.name], '.zip.tmp'))
          begin
            Zip.continue_on_exists_proc = true
            Zip::File.open(configuration_tmp, Zip::File::CREATE) do |zipfile|
              zip_file_path = File.basename(configuration, ".zip")
              zipfile.mkdir zip_file_path

              # Copy target files into archive
              zip_targets = []
              @targets.each do |target_name, target|
                entries = Dir.entries(target.dir) - %w(. ..)
                zip_target = File.join(zip_file_path, target.original_name)
                # Check the stored list of targets. We can't ask the zip file
                # itself because it's in progress and hasn't been saved
                unless zip_targets.include?(zip_target)
                  write_zip_entries(target.dir, entries, zip_target, zipfile)
                  zip_targets << zip_target
                end
              end

              # Create custom system.txt file
              zipfile.get_output_stream(File.join(zip_file_path, 'system.txt')) do |file|
                @targets.each do |target_name, target|
                  target_filename = File.basename(target.filename)
                  target_filename = nil unless File.exist?(target.filename)
                  # Create a newline character since Zip opens files in binary mode
                  newline = Kernel.is_windows? ? "\r\n" : "\n"
                  if target.substitute
                    file.write "DECLARE_TARGET #{target.original_name} #{target.name} #{target_filename}#{newline}"
                  else
                    file.write "DECLARE_TARGET #{target.name} nil #{target_filename}#{newline}"
                  end
                end
              end
            end
            File.rename(configuration_tmp, configuration)
            File.chmod(0444, configuration) # Mark readonly
          rescue Exception => error
            Logger.error "Problem saving configuration to #{configuration}: #{error.class}:#{error.message}\n#{error.backtrace.join("\n")}\n"
          end
        end
      end
    end

    def load_packets_internal(configuration_name = nil)
      # Determine hashing over all targets cmd_tlm files
      cmd_tlm_files = []
      additional_data = ''
      @targets.each do |target_name, target|
        cmd_tlm_files << target.filename if File.exist?(target.filename)
        cmd_tlm_files.concat(target.requires)
        cmd_tlm_files.concat(target.cmd_tlm_files)
        if target.substitute
          additional_data << target.original_name
          additional_data << target.name
        else
          additional_data << target.original_name
        end
      end

      hashing_result = Cosmos.hash_files(cmd_tlm_files + @additional_hashing_files, additional_data, @hashing_algorithm)
      hash_string = hashing_result.hexdigest
      # Only use at most, 32 characters of the hex
      hash_string = hash_string[-32..-1] if hash_string.length >= 32

      # Build filename for marshal file
      marshal_filename = File.join(@paths['TMP'], 'marshal_' << hash_string << '.bin')

      # Attempt to load marshal file
      config = Cosmos.marshal_load(marshal_filename)
      if config
        update_config(config)
        @config.name = configuration_name if configuration_name

        # Marshal file load successful
        Logger.info "Marshal load success: #{marshal_filename}"
        @config.warnings.each {|warning| Logger.warn(warning)} if @config.warnings
      else
        # Marshal file load failed - Manually load configuration
        @config = PacketConfig.new
        @commands = Commands.new(@config)
        @telemetry = Telemetry.new(@config)
        @limits = Limits.new(@config)

        @targets.each do |target_name, target|
          target.cmd_tlm_files.each do |cmd_tlm_file|
            begin
              @config.process_file(cmd_tlm_file, target.name)
            rescue Exception => err
              Logger.error "Problem processing #{cmd_tlm_file}."
              raise err
            end
          end
        end

        # Create marshal file for next time
        if configuration_name
          @config.name = configuration_name
        else
          @config.name = hash_string
        end

        Cosmos.marshal_dump(marshal_filename, @config)
      end
      setup_system_meta()

      @initial_config = @config unless @initial_config
      save_configuration()
    end

    def load_packets(configuration_name = nil, take_mutex = true)
      if take_mutex
        @@instance_mutex.synchronize do
          load_packets_internal(configuration_name)
        end
      else
        load_packets_internal(configuration_name)
      end
    end

    def setup_system_meta
      # Ensure SYSTEM META is defined and defined correctly
      begin
        if @commands.target_names.include?("SYSTEM")
          pkts = @commands.packets('SYSTEM')
          # User should not define COMMAND SYSTEM META as we build it to match TELEMETRY
          raise "COMMAND SYSTEM META defined" if pkts.keys.include?('META')
        end
        tlm_meta = @telemetry.packet('SYSTEM', 'META')
        item = tlm_meta.get_item('PKTID')
        raise "PKTID incorrect" unless (item.bit_size == 8) && (item.bit_offset == 0)
        item = tlm_meta.get_item('CONFIG')
        raise "CONFIG incorrect" unless (item.bit_size == 256) && (item.bit_offset == 8)
        item = tlm_meta.get_item('COSMOS_VERSION')
        raise "COSMOS_VERSION incorrect" unless (item.bit_size == 240) && (item.bit_offset == 264)
        item = tlm_meta.get_item('USER_VERSION')
        raise "USER_VERSION incorrect" unless (item.bit_size == 240) && (item.bit_offset == 504)
        item = tlm_meta.get_item('RUBY_VERSION')
        raise "RUBY_VERSION incorrect" unless (item.bit_size == 240) && (item.bit_offset == 744)
        cmd_meta = build_cmd_system_meta()
      rescue => err
        Logger.error "SYSTEM META not defined correctly due to #{err.message} - defaulting"
        tlm_meta = build_tlm_system_meta()
        cmd_meta = build_cmd_system_meta()
      end

      # Initialize the meta packet (if given init filename)
      if @meta_init_filename
        parser = ConfigParser.new("https://ballaerospace.github.io/cosmos-website/docs/v4/cmdtlm")
        Cosmos.set_working_dir do
          parser.parse_file(@meta_init_filename) do |keyword, params|
            begin
              item = tlm_meta.get_item(keyword)
              if (item.data_type == :STRING) || (item.data_type == :BLOCK)
                value = params[0]
              else
                value = params[0].convert_to_value
              end
              tlm_meta.write(keyword, value)
            rescue => err
              raise parser.error(err, "ITEM_NAME VALUE")
            end
          end
        end
      end

      # Setup fixed part of SYSTEM META packet
      tlm_meta.write('PKTID', 1)
      tlm_meta.write('CONFIG', @config.name)
      tlm_meta.write('COSMOS_VERSION', "#{COSMOS_VERSION}")
      tlm_meta.write('USER_VERSION', USER_VERSION) if defined? USER_VERSION
      tlm_meta.write('RUBY_VERSION', "#{RUBY_VERSION}p#{RUBY_PATCHLEVEL}")

      cmd_meta.buffer = tlm_meta.buffer
      cmd_meta.received_time = Time.now.sys
      tlm_meta.received_time = Time.now.sys
    end

    def build_cmd_system_meta
      cmd_meta = Packet.new('SYSTEM', 'META', :BIG_ENDIAN)
      cmd_meta.disabled = true
      tlm_meta = @telemetry.packet('SYSTEM', 'META')
      tlm_meta.sorted_items.each do |item|
        # Ignore reserved items as these are all DERIVED and thus will throw an exception
        # in CommandSender since they don't have write conversions due to:
        # commands.build_cmd -> packet.restore_defaults -> packet.write_item
        next if Packet::RESERVED_ITEM_NAMES.include?(item.name)
        item = cmd_meta.define(item.clone)
        # Define defaults so commands.build_cmd -> packet.restore_defaults will work
        if item.array_size
          item.default = []
        else
          case item.data_type
          when :INT, :UINT
            item.default = 0
          when :FLOAT
            item.default = 0.0
          when :STRING, :BLOCK
            item.default = ''
          end
        end
      end
      @config.commands['SYSTEM'] ||= {}
      @config.commands['SYSTEM']['META'] = cmd_meta
      cmd_meta
    end

    def build_tlm_system_meta
      tlm_meta = Packet.new('SYSTEM', 'META', :BIG_ENDIAN)
      tlm_meta.define_reserved_items()
      item = tlm_meta.append_item('PKTID', 8, :UINT, nil, :BIG_ENDIAN, :ERROR, nil, nil, nil, 1)
      item.description = 'Packet Id'
      item.meta["READ_ONLY"] = []
      item = tlm_meta.append_item('CONFIG', 32 * 8, :STRING)
      item.description = 'Configuration Name'
      item.meta["READ_ONLY"] = []
      item = tlm_meta.append_item('COSMOS_VERSION', 30 * 8, :STRING)
      item.description = 'COSMOS Version'
      item.meta["READ_ONLY"] = []
      item = tlm_meta.append_item('USER_VERSION', 30 * 8, :STRING)
      item.description = 'User Project Version'
      item.meta["READ_ONLY"] = []
      item = tlm_meta.append_item('RUBY_VERSION', 30 * 8, :STRING)
      item.description = 'Ruby Version'
      item.meta["READ_ONLY"] = []
      @config.telemetry['SYSTEM'] ||= {}
      @config.telemetry['SYSTEM']['META'] = tlm_meta
      tlm_meta
    end
  end
end
