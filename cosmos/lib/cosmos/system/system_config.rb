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

require 'cosmos/config/config_parser'
require 'cosmos/packets/packet_config'
require 'cosmos/packets/commands'
require 'cosmos/packets/telemetry'
require 'cosmos/packets/limits'
require 'cosmos/system/target'
require 'cosmos/logs'
require 'fileutils'
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
  class SystemConfig
    # @return [String] Base path of the configuration
    attr_reader :userpath
    # @return [Boolean] Whether to use sound for alerts
    attr_reader :sound
    # @return [Boolean] Whether to use DNS to lookup IP addresses or not
    attr_reader :use_dns
    # @return [Hash<String,Target>] Hash of all the known targets
    attr_reader :targets
    # @return [Integer] The number of seconds before a telemetry packet is considered stale
    attr_reader :staleness_seconds
    # @return [Boolean] Whether to use UTC or local times
    attr_reader :use_utc
    # @return [Hash<String,String>] Hash of the text/color to use for the classificaiton banner
    attr_reader :classificiation_banner

    # @param filename [String] Full path to the system configuration file to
    #   read. Be default this is <Cosmos::USERPATH>/config/system/system.txt
    def initialize(filename)
      reset_variables(filename)
    end

    # Resets the System's internal state to defaults.
    #
    # @param filename [String] Path to system.txt config file to process. Defaults to config/system/system.txt
    def reset_variables(filename)
      @targets = {}
      @config = nil
      @commands = nil
      @telemetry = nil
      @limits = nil
      @sound = false
      @use_dns = false
      @staleness_seconds = 30
      @use_utc = false
      @meta_init_filename = nil
      @userpath = File.expand_path(File.join(File.dirname(filename), '..', '..'))
      process_file(filename, File.join(@userpath, 'config', 'targets'))
      @initial_filename = filename
      @initial_config = nil
      @config_blacklist = {}
    end

    # Process the system.txt configuration file
    #
    # @param filename [String] The configuration file
    # @param targets_config_dir [String] The configuration directory to
    #   search for the target command and telemetry files. Pass nil to look in
    #   the default location of <USERPATH>/config/targets.
    def process_file(filename, targets_config_dir)
      Cosmos.set_working_dir(@userpath) do
        parser = ConfigParser.new("http://cosmosc2.com/docs/v5")

        # First pass - Everything except targets
        parser.parse_file(filename) do |keyword, parameters|
          case keyword
          when 'AUTO_DECLARE_TARGETS', 'DECLARE_TARGET', 'DECLARE_GEM_TARGET', 'DECLARE_GEM_MULTI_TARGET'
            # Will be handled by second pass

          when 'PORT', 'LISTEN_HOST', 'CONNECT_HOST', 'PATH', 'DEFAULT_PACKET_LOG_WRITER', 'DEFAULT_PACKET_LOG_READER',
            'ALLOW_ACCESS', 'ADD_HASH_FILE', 'ADD_MD5_FILE', 'HASHING_ALGORITHM'
            # Not used by COSMOS 5

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

          when 'STALENESS_SECONDS'
            parser.verify_num_parameters(1, 1, "#{keyword} <Value in Seconds>")
            @staleness_seconds = Integer(parameters[0])

          when 'META_INIT'
            parser.verify_num_parameters(1, 1, "#{keyword} <Filename>")
            @meta_init_filename = ConfigParser.handle_nil(parameters[0])

          when 'TIME_ZONE_UTC'
            parser.verify_num_parameters(0, 0, "#{keyword}")
            @use_utc = true

          when 'CLASSIFICATION'
            parser.verify_num_parameters(2, 4, "#{keyword} <Display_Text> <Color Name|Red> <Green> <Blue>")
            # Determine if the COSMOS color already exists, otherwise create a new one
            if Cosmos.constants.include? parameters[1].upcase.to_sym
              # We were given a named color that already exists in COSMOS
              color = eval("Cosmos::#{parameters[1].upcase}")
            else
              if parameters.length < 4
                # We were given a named color, but it didn't exist in COSMOS already
                color = Cosmos.getColor(parameters[1].upcase)
              else
                # We were given RGB values
                color = Cosmos.getColor(parameters[1], parameters[2], parameters[3])
              end
            end

            @classificiation_banner = { 'display_text' => parameters[0],
                                       'color' => color }

          else
            # blank lines will have a nil keyword and should not raise an exception
            raise parser.error("Unknown keyword '#{keyword}'") if keyword
          end # case keyword
        end # parser.parse_file

        # Explicitly set up time to use UTC or local
        if @use_utc
          Time.use_utc()
        else
          Time.use_local()
        end

        # Second pass - Process targets
        process_targets(parser, filename, targets_config_dir)
      end # Cosmos.set_working_dir
    end # def process_file

    # Parse the system.txt configuration file looking for keywords associated
    # with targets and create all the Target instances in the system.
    #
    # @param parser [ConfigParser] Parser created by process_file
    # @param filename (see #process_file)
    # @param targets_config_dir (see #process_file)
    def process_targets(parser, filename, targets_config_dir)
      parser.parse_file(filename) do |keyword, parameters|
        case keyword
        when 'AUTO_DECLARE_TARGETS'
          usage = "#{keyword}"
          parser.verify_num_parameters(0, 0, usage)
          path = File.join(@userpath, 'config', 'targets')
          unless File.exist? path
            raise parser.error("#{path} must exist", usage)
          end
          dirs = []
          configuration_dir = File.join(@userpath, 'config', 'targets')
          Dir.foreach(configuration_dir) { |dir_filename| dirs << dir_filename }
          dirs.sort!
          dirs.each do |dir_filename|
            if dir_filename[0] != '.'
              if dir_filename == dir_filename.upcase
                # If any of the targets original directory name matches the
                # current directory then it must have been already processed by
                # DECLARE_TARGET so we skip it.
                next if @targets.select {|name, target| target.original_name == dir_filename }.length > 0
                next if dir_filename == 'SYSTEM'
                target = Target.new(dir_filename, nil, targets_config_dir)
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

          if targets_config_dir
            folder_name = File.join(targets_config_dir, target_name)
          else
            folder_name = File.join(@userpath, 'config', 'targets', target_name)
          end
          unless Dir.exist?(folder_name)
            raise parser.error("Target folder must exist '#{folder_name}'.")
          end

          substitute_name = nil
          substitute_name = ConfigParser.handle_nil(parameters[1])
          if substitute_name
            substitute_name = substitute_name.to_s.upcase
            original_name = target_name
            target_name = substitute_name
          else
            original_name = nil
          end

          target = Target.new(target_name, original_name, targets_config_dir, ConfigParser.handle_nil(parameters[2]))
          @targets[target.name] = target

        when 'DECLARE_GEM_TARGET'
          usage = "#{keyword} <GEM NAME> <SUBSTITUTE TARGET NAME (Optional)> <TARGET FILENAME (Optional - defaults to target.txt)>"
          parser.verify_num_parameters(1, 3, usage)
          # Remove 'cosmos' from the gem name 'cosmos-power-supply'
          target_name = parameters[0].split('-')[1..-1].join('-').to_s.upcase
          gem_dir = Gem::Specification.find_by_name(parameters[0]).gem_dir
          substitute_name = nil
          substitute_name = ConfigParser.handle_nil(parameters[1])
          if substitute_name
            substitute_name = substitute_name.to_s.upcase
            original_name = target_name
            target_name = substitute_name
          else
            original_name = nil
          end
          target = Target.new(target_name, original_name, targets_config_dir, ConfigParser.handle_nil(parameters[2]), gem_dir)
          @targets[target.name] = target

        when 'DECLARE_GEM_MULTI_TARGET'
          usage = "#{keyword} <GEM NAME> <TARGET NAME> <SUBSTITUTE TARGET NAME (Optional)> <TARGET FILENAME (Optional - defaults to target.txt)>"
          parser.verify_num_parameters(2, 4, usage)
          target_name = parameters[1].to_s.upcase
          gem_dir = Gem::Specification.find_by_name(parameters[0]).gem_dir
          gem_dir = File.join(gem_dir, target_name)
          substitute_name = nil
          substitute_name = ConfigParser.handle_nil(parameters[2])
          if substitute_name
            substitute_name = substitute_name.to_s.upcase
            original_name = target_name
            target_name = substitute_name
          else
            original_name = nil
          end
          target = Target.new(target_name, original_name, targets_config_dir, ConfigParser.handle_nil(parameters[3]), gem_dir)
          @targets[target.name] = target

        end # case keyword
      end # parser.parse_file

      # Make sure SYSTEM target is always present and added last
      unless @targets.key?('SYSTEM')
        target = Target.new('SYSTEM', nil, targets_config_dir)
        @targets[target.name] = target
      end
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
              # check for targets in other directories 1 level deep
              next if dir_filename[0] == '.'               # skip dot directories and ".."
              next if dir_filename != dir_filename.upcase  # skip non uppercase directories
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

    def save_configuration
      Cosmos.set_working_dir(@userpath) do
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

  end
end
