# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/config/config_parser'

module Cosmos
  # Target encapsulates the information about a COSMOS target. Targets are
  # accessed through interfaces and have command and telemetry definition files
  # which define their access.
  class Target
    # @return [String] Name of the target. This can be overridden when
    #   the system processes the target.
    attr_reader :name

    # @return [String] Name of the target as defined by the
    #   target directory name. This name does not change.
    attr_reader :original_name

    # @return [Boolean] Indicates if substitution should take place or not
    attr_reader :substitute

    # @return [Array<String>] List of filenames that must be required by Ruby
    #   before parsing the command and telemetry definitions for this target
    attr_reader :requires

    # @return [Array<String>] List of parameters that should be ignored. Tools
    #   which access this target should not display or manipulate these
    #   parameters.
    attr_reader :ignored_parameters

    # @return [Array<String>] List of items that should be ignored. Tools
    #   which access this target should not display or manipulate these
    #   items.
    attr_reader :ignored_items

    # @return [Boolean] Whether auto screen substitution is enabled
    attr_reader :auto_screen_substitute

    # @return [Array<String>] List of configuration files which define the
    #   commands and telemetry for this target
    attr_reader :cmd_tlm_files

    # @return [String] Target filename for this target
    attr_reader :filename

    # @return [String] The directory which contains this target. The directory
    #   is by default <USERPATH>/config/targets/<original_name>. Once a target
    #   has been processed it is copied to a saved configuration location and
    #   the dir will be updated to return this location.
    attr_reader :dir

    # @return [Interface] The interface used to access the target
    attr_accessor :interface

    # @return [Integer] The number of command packets send to this target
    attr_accessor :cmd_cnt

    # @return [Integer] The number of telemetry packets received from this target
    attr_accessor :tlm_cnt

    # Creates a new target by processing the target.txt file in the directory
    # given by the path joined with the target_name. Records all the command
    # and telemetry definition files found in the targets cmd_tlm directory.
    # System uses this list and processes them using PacketConfig.
    #
    # @param target_name [String] The name of the target. This must match the
    #   directory name which contains the target.
    # @param substitute_name [String] The name COSMOS should use when refering
    #   to the target. All accesses will ignore the original target_name.
    # @param path [String] Path to the target directory. Passing nil sets the
    #   path to the default of <USERPATH>/config/targets.
    # @param target_filename [String] Configuration file for the target. Normally
    #   target.txt
    # @param gem_path [String] Path to the gem file or nil if there is no gem
    def initialize(target_name, substitute_name = nil, path = nil, target_filename = nil, gem_path = nil)
      @requires = []
      @ignored_parameters = []
      @ignored_items = []
      @cmd_tlm_files = []
      @auto_screen_substitute = false
      @interface = nil
      @routers = []
      @cmd_cnt = 0
      @tlm_cnt = 0

      # Determine the target name using substitution if given
      @original_name = target_name.clone.upcase.freeze
      if substitute_name
        @substitute = true
        @name = substitute_name.clone.upcase.freeze
      else
        @substitute = false
        @name = @original_name
      end

      @dir = get_target_dir(path, @original_name, gem_path)
      # Parse the target.txt file if it exists
      @filename = process_target_config_file(@dir, @name, target_filename)
      # If target.txt didn't specify specific cmd/tlm files then add everything
      if @cmd_tlm_files.empty?
        @cmd_tlm_files = add_all_cmd_tlm(@dir)
      else
        add_cmd_tlm_partials(@dir)
      end
    end

    # Parses the target configuration file
    #
    # @param filename [String] The target configuration file to parse
    def process_file(filename)
      Logger.instance.info "Processing target definition in file '#{filename}'"
      parser = ConfigParser.new
      parser.parse_file(filename) do |keyword, parameters|
        case keyword
        when 'REQUIRE'
          usage = "#{keyword} <FILENAME>"
          parser.verify_num_parameters(1, 1, usage)
          found = false
          begin
            # Determine if this file is in our target lib and should be namespaced
            filename = File.join(@dir, 'lib', parameters[0])
            if File.exist? filename
              const = find_or_create_const(@name)
              const.module_eval(File.read(File.join(@dir, 'lib', parameters[0])))
              found = true
            end
          rescue Exception => error
            raise parser.error(error.message)
          end

          # Now simply require the file to allow it to be overriden elsewhere
          begin
            Cosmos.require_file(parameters[0], false)
            @requires << parameters[0]
          rescue LoadError => error
            # Don't raise the error if it was found in the target lib dir
            raise error unless found
          end

        when 'IGNORE_PARAMETER', 'IGNORE_ITEM'
          usage = "#{keyword} <#{keyword.split('_')[1]} NAME>"
          parser.verify_num_parameters(1, 1, usage)
          @ignored_parameters << parameters[0].upcase if keyword.include?("PARAMETER")
          @ignored_items << parameters[0].upcase if keyword.include?("ITEM")

        when 'COMMANDS', 'TELEMETRY'
          usage = "#{keyword} <FILENAME>"
          parser.verify_num_parameters(1, 1, usage)
          filename = File.join(@dir, 'cmd_tlm', parameters[0])
          raise parser.error("#{filename} not found") unless File.exist?(filename)
          @cmd_tlm_files << filename

        when 'AUTO_SCREEN_SUBSTITUTE'
          usage = "#{keyword}"
          parser.verify_num_parameters(0, 0, usage)
          @auto_screen_substitute = true

        else
          # blank lines will have a nil keyword and should not raise an exception
          raise parser.error("Unknown keyword '#{keyword}'") if keyword
        end # case keyword
      end
    end

    protected

    # Find the specified constant under the Cosmos namespace or create it
    def find_or_create_const(str)
      return Cosmos.const_get(str) if Cosmos.const_defined?(str)
      return Cosmos.const_set(str, Module.new)
    end

    # Get the target directory and add the target's lib folder to the
    # search path if it exists
    def get_target_dir(path, name, gem_path)
      if gem_path
        dir = gem_path
      else
        path = File.join(USERPATH,'config','targets') unless path
        dir = File.join(path, name)
      end
      # Don't add target/lib dir to search path
      # Files in target/lib must be explicitly required in target.txt
      proc_dir = File.join(dir, 'procedures')
      Cosmos.add_to_search_path(proc_dir, false) if File.exist?(proc_dir)
      dir
    end

    # Process the target's configuration file if it exists
    def process_target_config_file(dir, name, target_filename)
      filename = File.join(dir, target_filename || 'target.txt')
      if File.exist?(filename)
        process_file(filename)
      else
        raise "Target file #{target_filename} for target #{name} does not exist" if target_filename
      end
      filename
    end

    # Automatically add all command and telemetry definitions to the list
    def add_all_cmd_tlm(dir)
      cmd_tlm_files = []
      if Dir.exist?(File.join(dir, 'cmd_tlm'))
        # Grab All *.txt files in the cmd_tlm folder and subfolders
        Dir[File.join(dir, 'cmd_tlm', '**', '*.txt')].each do |filename|
          cmd_tlm_files << filename
        end
        # Grab All *.xtce files in the cmd_tlm folder and subfolders
        Dir[File.join(dir, 'cmd_tlm', '**', '*.xtce')].each do |filename|
          cmd_tlm_files << filename
        end
      end
      cmd_tlm_files.sort!
    end

    # Make sure all partials are included in the cmd_tlm list for the MD5 calculation
    def add_cmd_tlm_partials(dir)
      partial_files = []
      if Dir.exist?(File.join(dir, 'cmd_tlm'))
        # Grab all _*.txt files in the cmd_tlm folder and subfolders
        Dir[File.join(dir, 'cmd_tlm', '**', '_*.txt')].each do |filename|
          partial_files << filename
        end
      end
      partial_files.sort!
      @cmd_tlm_files.concat(partial_files)
      @cmd_tlm_files.uniq!
    end
  end
end
