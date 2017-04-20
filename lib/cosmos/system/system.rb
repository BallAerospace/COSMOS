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
require 'bundler'

module Cosmos

  # System is the primary entry point into the COSMOS framework. It captures
  # system wide configuration items such as the available ports and paths to
  # various files used by the system. The #commands, #telemetry, and #limits
  # class variables are the primary access points for applications. The
  # #targets variable provides access to all the targets defined by the system.
  # Its primary responsibily is to load the system configuration file and
  # create all the Target instances. It also saves and restores configurations
  # using a MD5 checksum over the entire configuration to detect changes.
  class System
    # @return [Hash<String,Fixnum>] Hash of all the known ports and their values
    instance_attr_reader :ports
    # @return [Hash<String,String>] Hash of all the known paths and their values
    instance_attr_reader :paths
    # @return [String] Arbitrary string containing the version
    instance_attr_reader :cmd_tlm_version
    # @return [PacketLogWriter] Class used to create log files
    instance_attr_reader :default_packet_log_writer
    # @return [PacketLogReader] Class used to read log files
    instance_attr_reader :default_packet_log_reader
    # @return [Boolean] Whether to use sound for alerts
    instance_attr_reader :sound
    # @return [Boolean] Whether to use DNS to lookup IP addresses or not
    instance_attr_reader :use_dns
    # @return [String] Stores the initial configuration file used when this
    #   System was initialized
    instance_attr_reader :initial_filename
    # @return [PacketDefinition] Stores the initial packet list used when this
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

    # Known COSMOS ports
    KNOWN_PORTS = ['CTS_API', 'TLMVIEWER_API', 'CTS_PREIDENTIFIED', 'CTS_CMD_ROUTER']
    # Known COSMOS paths
    KNOWN_PATHS = ['LOGS', 'TMP', 'SAVED_CONFIG', 'TABLES', 'HANDBOOKS', 'PROCEDURES']

    @@instance = nil
    @@instance_mutex = Mutex.new

    # Create a new System object. Note, this should not be called directly but
    # you should instead use System.instance and treat this class as a
    # singleton.
    #
    # @param filename [String] Full path to the system configuration file to
    #   read. Be default this is <Cosmos::USERPATH>/config/system/system.txt
    def initialize(filename = nil)
      raise "Cosmos::System created twice" unless @@instance.nil?
      @targets = {}
      @targets['UNKNOWN'] = Target.new('UNKNOWN')
      @config = nil
      @commands = nil
      @telemetry = nil
      @limits = nil
      @cmd_tlm_version = nil
      @default_packet_log_writer = PacketLogWriter
      @default_packet_log_reader = PacketLogReader
      @sound = false
      @use_dns = false
      @acl = nil
      @staleness_seconds = 30
      @limits_set = :DEFAULT

      @ports = {}
      @ports['CTS_API'] = 7777
      @ports['TLMVIEWER_API'] = 7778
      @ports['CTS_PREIDENTIFIED'] = 7779
      @ports['CTS_CMD_ROUTER'] = 7780

      @paths = {}
      @paths['LOGS'] = File.join(USERPATH, 'outputs', 'logs')
      @paths['TMP'] = File.join(USERPATH, 'outputs', 'tmp')
      @paths['SAVED_CONFIG'] = File.join(USERPATH, 'outputs', 'saved_config')
      @paths['TABLES'] = File.join(USERPATH, 'outputs', 'tables')
      @paths['HANDBOOKS'] = File.join(USERPATH, 'outputs', 'handbooks')
      @paths['PROCEDURES'] = [File.join(USERPATH, 'procedures')]

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
          CmdTlmServer.instance.post_limits_event(:LIMITS_SET, System.limits_set) if defined? CmdTlmServer and CmdTlmServer.instance
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
      acl_list = []
      all_allowed = false
      first_procedures_path = true

      Cosmos.set_working_dir do
        parser = ConfigParser.new

        # First pass - Everything except targets
        parser.parse_file(filename) do |keyword, parameters|
          case keyword
          when 'AUTO_DECLARE_TARGETS', 'DECLARE_TARGET', 'DECLARE_GEM_TARGET'
            # Will be handled by second pass

          when 'PORT'
            usage = "#{keyword} <PORT NAME> <PORT VALUE>"
            parser.verify_num_parameters(2, 2, usage)
            port_name = parameters[0].to_s.upcase
            @ports[port_name] = Integer(parameters[1])
            Logger.warn("Unknown port name given: #{port_name}") unless KNOWN_PORTS.include?(port_name)

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
            usage = "#{keyword} <FILENAME>"
            parser.verify_num_parameters(1, 1, usage)
            @default_packet_log_writer = Cosmos.require_class(parameters[0])

          when 'DEFAULT_PACKET_LOG_READER'
            usage = "#{keyword} <FILENAME>"
            parser.verify_num_parameters(1, 1, usage)
            @default_packet_log_reader = Cosmos.require_class(parameters[0])

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
                if !((first_char =~ /[1234567890]/) or (first_char == '*') or (addr.upcase == 'ALL'))
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

          when 'CMD_TLM_VERSION'
            usage = "#{keyword} <VERSION>"
            parser.verify_num_parameters(1, 1, usage)
            @cmd_tlm_version = parameters[0]

          else
            # blank lines will have a nil keyword and should not raise an exception
            raise parser.error("Unknown keyword '#{keyword}'") if keyword
          end # case keyword
        end # parser.parse_file

        @acl = ACL.new(acl_list, ACL::ALLOW_DENY) unless acl_list.empty?

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
          system_found = false
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
                if dir_filename == 'SYSTEM'
                  system_found = true
                  next
                end
                target = Target.new(dir_filename)
                @targets[target.name] = target
              else
                raise parser.error("Target folder must be uppercase: '#{dir_filename}'")
              end
            end
          end

          auto_detect_gem_based_targets()

          if system_found
            target = Target.new('SYSTEM')
            @targets[target.name] = target
          end

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

        end # case keyword
      end # parser.parse_file
    end

    # Load the specified configuration by iterating through the SAVED_CONFIG
    # directory looking for a matching MD5 sum. Updates the internal state so
    # subsequent commands and telemetry methods return the new configuration.
    #
    # @param name [String] MD5 string which identifies the
    #   configuration. Pass nil to load the default configuration.
    # @return [String, Exception/nil] The actual configuration loaded
    def load_configuration(name = nil)
      if name and @config
        # Make sure they're requesting something other than the current
        # configuration.
        if name != @config.name
          # If they want the initial configuration we can just swap out the
          # current configuration without doing any file processing
          if name == @initial_config.name
            update_config(@initial_config)
          else
            # Look for the requested configuration in the saved configurations
            configuration_directory = find_configuration(name)
            if configuration_directory
              # We found the configuration requested. Reprocess the system.txt
              # and reload the packets
              begin
                process_file(File.join(configuration_directory, 'system.txt'), configuration_directory)
                load_packets(name)
              rescue Exception => error
                # Failed to load - Restore initial
                update_config(@initial_config)
                return @config.name, error
              end
            else
              # We couldn't find the configuration request. Reload the
              # initial configuration
              update_config(@initial_config)
            end
          end
        end
      else
        # Ensure packets have been lazy loaded
        System.commands
        update_config(@initial_config)
      end
      return @config.name, nil
    end

    # (see #load_configuration)
    def self.load_configuration(name = nil)
      return self.instance.load_configuration(name)
    end

    protected

    def auto_detect_gem_based_targets
      Bundler.load.specs.each do |spec|
        spec_name_split = spec.name.split('-')
        if spec_name_split.length > 1 and spec_name_split[0] == 'cosmos'
          # Filter to just targets and not tools and other extensions
          if File.exist?(File.join(spec.gem_dir, 'cmd_tlm'))
            target_name = spec_name_split[1..-1].join('-').to_s.upcase
            target = Target.new(target_name, nil, nil, nil, spec.gem_dir)
            @targets[target.name] = target
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

    def find_configuration(name)
      Cosmos.set_working_dir do
        Dir.foreach(@paths['SAVED_CONFIG']) do |filename|
          full_path = File.join(@paths['SAVED_CONFIG'], filename)
          if Dir.exist?(full_path) and filename[-32..-1] == name
            return full_path
          end
        end
      end
      nil
    end

    def save_configuration
      Cosmos.set_working_dir do
        configuration_directory = find_configuration(@config.name)
        configuration_directory = File.join(@paths['SAVED_CONFIG'], File.build_timestamped_filename([@config.name], '')) unless configuration_directory
        unless Dir.exist?(configuration_directory)
          begin
            # Create the directory
            FileUtils.mkdir_p(configuration_directory)

            # Copy target files into directory
            @targets.each do |target_name, target|
              destination_dir = File.join(configuration_directory, target.original_name)
              unless Dir.exist?(destination_dir)
                FileUtils.cp_r(target.dir, destination_dir)
              end
            end

            # Create custom system.txt file
            File.open(File.join(configuration_directory, 'system.txt'), 'w') do |file|
              @targets.each do |target_name, target|
                target_filename = File.basename(target.filename)
                target_filename = nil unless File.exist?(target.filename)
                if target.substitute
                  file.puts "DECLARE_TARGET #{target.original_name} #{target.name} #{target_filename}"
                else
                  file.puts "DECLARE_TARGET #{target.name} nil #{target_filename}"
                end
              end
            end
          rescue Exception => error
            Logger.error "Problem saving configuration to #{configuration_directory}: #{error.class}:#{error.message}"
          end
        end
      end
    end

    def load_packets(configuration_name = nil)
      # Determine MD5 over all targets cmd_tlm files
      cmd_tlm_files = []
      additional_data = ''
      @targets.each do |target_name, target|
        cmd_tlm_files << target.filename if File.exist?(target.filename)
        cmd_tlm_files.concat(target.cmd_tlm_files)
        if target.substitute
          additional_data << target.original_name
          additional_data << target.name
        else
          additional_data << target.original_name
        end
      end

      md5 = Cosmos.md5_files(cmd_tlm_files, additional_data)
      md5_string = md5.hexdigest

      # Build filename for marshal file
      marshal_filename = File.join(@paths['TMP'], 'marshal_' << md5_string << '.bin')

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
          @config.name = md5_string
        end
        Cosmos.marshal_dump(marshal_filename, @config)
      end

      @initial_config = @config unless @initial_config
      save_configuration()
    end

  end # class System

end # module Cosmos
