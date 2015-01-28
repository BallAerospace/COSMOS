# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/config/config_parser'
require 'ostruct'

module Cosmos

  # Reads and interprets the Launcher configuration file
  class LauncherConfig

    # Launcher title
    attr_reader :title

    # Array for tool font settings [font_name, font_size]
    attr_reader :tool_font_settings

    # Array for label font settings [font_name, font_size]
    attr_reader :label_font_settings

    # Array of [[item_type, text, shell command, icon filename, variable params], ...]
    # Where variable params is nil or an array of [[parameter name, parameter value], ...]
    attr_reader :items

    # Number of columns per row
    attr_reader :num_columns

    # Processes a file and adds in the configuration defined in the file
    #
    # @param filename [String] Name of the configuration file to parse
    def initialize(filename)
      @title = 'COSMOS Launcher'
      @tool_font_settings  = ['Arial', 12]
      @label_font_settings = ['Arial', 16]
      @num_columns = 4
      @items = []

      if File.exist?(filename.to_s)
        parse_file(filename)
      else
        raise "Launcher configuration file does not exist: #{filename}"
      end
    end # def initialize

    # Create a ConfigParser and parse all the lines in the configuration file
    #
    # @param filename [String] Name of the configuration file to parse
    def parse_file(filename)
      multitool = nil

      # Loop over each line of the configuration file
      parser = ConfigParser.new
      parser.parse_file(filename) do |keyword, params|
        # Handle each keyword
        case keyword

        when 'TOOL'
          parse_tool(parser, params, multitool)

        when 'MULTITOOL_START'
          parser.verify_num_parameters(1, 2, "MULTITOOL_START <Button Text> <Icon Filename (optional)>")
          multitool = OpenStruct.new
          multitool.text = params[0]
          multitool.icon_filename = ConfigParser.handle_nil(params[1])
          multitool.icon_filename = 'multi.png' unless multitool.icon_filename
          multitool.settings = []

        when 'MULTITOOL_END'
          parser.verify_num_parameters(0, 0, "MULTITOOL_END")
          raise parser.error("No TOOLs defined within the MULTITOOL") if multitool.settings.select {|setting| setting[0] == :TOOL }.empty?
          @items << [:MULTITOOL, multitool.text, multitool.settings, true, multitool.icon_filename, nil]
          multitool = nil

        when 'DELAY'
          if multitool
            parser.verify_num_parameters(1, 1, "DELAY <Delay in seconds>")
            multitool.settings << [:DELAY, Float(params[0]), true]
          else
            raise parser.error("DELAY keyword only valid within MULTITOOL")
          end

        when 'DIVIDER'
          parser.verify_num_parameters(0, 0, "DIVIDER")
          @items << [:DIVIDER, nil, nil, nil, nil]

        when 'LABEL'
          parser.verify_num_parameters(1, 1, "LABEL <Label Text>")
          @items << [:LABEL, params[0], nil, nil, nil]

        when 'TOOL_FONT', 'LABEL_FONT'
          usage = "#{keyword} <Font Name> <Font Size>"
          parser.verify_num_parameters(2, 2, usage)
          begin
            @tool_font_settings = [params[0], Integer(params[1])] if keyword == 'TOOL_FONT'
            @label_font_settings = [params[0], Integer(params[1])] if keyword == 'LABEL_FONT'
          rescue ArgumentError
            raise parser.error("#{usage} passed '#{params[0]} #{params[1]}'")
          end

        when 'TITLE'
          parser.verify_num_parameters(1, 1, "TITLE <Title Text>")
          @title = params[0]

        when 'NUM_COLUMNS'
          usage = "NUM_COLUMNS <Num Columns>"
          parser.verify_num_parameters(1, 1, usage)
          begin
            @num_columns = Integer(params[0])
          rescue ArgumentError
            raise parser.error("#{usage} passed '#{params[0]}'")
          end

        when 'DONT_CAPTURE_IO'
          parser.verify_num_parameters(0, 0, "DONT_CAPTURE_IO")
          if multitool
            if multitool.settings[-1].nil? || multitool.settings[-1][0] != :TOOL
              raise parser.error("DONT_CAPTURE_IO must follow a TOOL")
            end
            multitool.settings[-1][2] = false
          else
            if @items[-1].nil? || @items[-1][0] != :TOOL
              raise parser.error("DONT_CAPTURE_IO must follow a TOOL")
            end
            @items[-1][3] = false
          end

        else # UNKNOWN
          raise parser.error("Unknown keyword '#{keyword}'.") if keyword
        end # case keyword
      end # parser.parse_file
    end

    protected

    def parse_tool(parser, params, multitool)
      if multitool
        parser.verify_num_parameters(1, 1, "TOOL <Shell command>")
        multitool.settings << [:TOOL, format_shell_command(parser, params[0]), true]
      else
        parser.verify_num_parameters(2, nil, "TOOL <Button Text> <Shell command> <Icon Filename (optional)> <Parameter Name #1 (optional)> <Parameter Value #1 (optional)> ...")
        variable_params = nil
        # Determine if there are parameters which will be displayed in a GUI
        # dialog when the tool starts
        if params.length > 3
          raise parser.error("Unbalanced variable params for #{params[0]}") if (params.length % 2) != 1
          variable_params = []
          params[3..-1].each_slice(2) { |variable_parameter| variable_params << variable_parameter }
        end
        @items << [:TOOL, params[0], format_shell_command(parser, params[1]), true, ConfigParser.handle_nil(params[2]), variable_params]
      end
    end

    def format_shell_command(parser, shell_command)
      formatted_command = ''
      case shell_command.split[0]
      when 'LAUNCH'
        formatted_command = parse_launch(shell_command)
      when 'LAUNCH_TERMINAL'
        formatted_command = parse_launch_terminal(shell_command)
      else
        # Nothing to do if they aren't using our keywords
        formatted_command = shell_command
      end
      formatted_command
    end

    def parse_launch(command)
      split = command.split
      if Kernel.is_mac? and File.exist?(File.join(USERPATH, 'tools', 'mac'))
        formatted = "open tools/mac/#{split[1]}.app --args #{split[2..-1].join(' ')}".strip
      else
        formatted = "RUBYW tools/#{split[1]} #{split[2..-1].join(' ')}".strip
      end
      formatted
    end

    def parse_launch_terminal(command)
      split = command.split
      if Kernel.is_mac?
        formatted = "osascript -e 'tell application \"Terminal\" to do script \"cd #{File.expand_path(USERPATH)} && ruby tools/#{split[1]} #{split[2..-1].join(' ')}\"' -e 'return'"
      elsif Kernel.is_windows?
        formatted = "start ruby tools/#{split[1]} #{split[2..-1].join(' ')}".strip
      else
        formatted = "gnome-terminal -e \"ruby tools/#{split[1]} #{split[2..-1].join(' ')}\""
      end

      if Kernel.is_windows?
        rubyw_sub = 'rubyw'
      else
        rubyw_sub = 'ruby'
      end

      formatted.gsub!('RUBYW', rubyw_sub)
      formatted
    end

  end # class LauncherConfig

end # module Cosmos
