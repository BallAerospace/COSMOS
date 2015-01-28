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
    def initialize(filename)
      # Initialize instance variables
      @title = 'COSMOS Launcher'
      @tool_font_settings  = ['Arial', 12]
      @label_font_settings = ['Arial', 16]
      @num_columns = 4
      @items = []

      if File.exist?(filename.to_s)
        multitool = false
        multitool_text = nil
        multitool_icon_filename = nil
        multitool_settings = nil

        # Loop over each line of the configuration file
        parser = ConfigParser.new
        parser.parse_file(filename) do |keyword, params|
          # Handle each keyword
          case keyword

          when 'TOOL'
            if multitool
              parser.verify_num_parameters(1, 1, "TOOL <Shell command>")
              multitool_settings << [:TOOL, format_shell_command(params[0]), true]
            else
              parser.verify_num_parameters(2, nil, "TOOL <Button Text> <Shell command> <Icon Filename (optional)> <Parameter Name #1 (optional)> <Parameter Value #1 (optional)> ...")
              variable_params = nil
              if params.length > 3
                raise parser.error("Unbalanced variable params for #{params[0]}") if (params.length % 2) != 1
                variable_params = []
                params[3..-1].each_slice(2) { |variable_parameter| variable_params << variable_parameter }
              end
              @items << [:TOOL, params[0], format_shell_command(params[1]), true, ConfigParser.handle_nil(params[2]), variable_params]
            end

          when 'MULTITOOL_START'
            parser.verify_num_parameters(1, 2, "MULTITOOL_START <Button Text> <Icon Filename (optional)>")
            multitool = true
            multitool_text = params[0]
            multitool_icon_filename = ConfigParser.handle_nil(params[1])
            multitool_icon_filename = 'multi.png' unless multitool_icon_filename
            multitool_settings = []

          when 'MULTITOOL_END'
            parser.verify_num_parameters(0, 0, "MULTITOOL_END")
            @items << [:MULTITOOL, multitool_text, multitool_settings, true, multitool_icon_filename, nil]
            multitool = false
            multitool_text = nil
            multitool_icon_filename = nil
            multitool_settings = nil

          when 'DELAY'
            if multitool
              parser.verify_num_parameters(1, 1, "DELAY <Delay in seconds>")
              multitool_settings << [:DELAY, Float(params[0]), true]
            else
              raise parser.error("DELAY keyword only valid within MULTITOOL")
            end

          when 'DIVIDER'
            parser.verify_num_parameters(0, 0, "DIVIDER")
            @items << [:DIVIDER, nil, nil, nil, nil]

          when 'LABEL'
            parser.verify_num_parameters(1, 1, "LABEL <Label Text>")
            @items << [:LABEL, params[0], nil, nil, nil]

          when 'TOOL_FONT'
            parser.verify_num_parameters(2, 2, "TOOL_FONT <Font Name> <Font Size>")
            @tool_font_settings = [params[0], Integer(params[1])]

          when 'LABEL_FONT'
            parser.verify_num_parameters(2, 2, "LABEL_FONT <Font Name> <Font Size>")
            @label_font_settings = [params[0], Integer(params[1])]

          when 'TITLE'
            parser.verify_num_parameters(1, 1, "TITLE <Title Text>")
            @title = params[0]

          when 'NUM_COLUMNS'
            parser.verify_num_parameters(1, 1, "NUM_COLUMNS <Num Columns>")
            @num_columns = params[0].to_i

          when 'DONT_CAPTURE_IO'
            parser.verify_num_parameters(0, 0, "DONT_CAPTURE_IO")
            if multitool
              if multitool_settings[-1].nil? || multitool_settings[-1][0] != :TOOL
                raise parser.error("DONT_CAPTURE_IO must follow a TOOL")
              end
              multitool_settings[-1][2] = false
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

      else
        raise "Launcher configuration file does not exist: #{filename}"
      end

    end # def initialize

    def format_shell_command(shell_command)
      if Kernel.is_windows?
        rubyw_sub = 'rubyw'
      else
        rubyw_sub = 'ruby'
      end

      split_command = shell_command.split
      if split_command[0] == 'LAUNCH'
        if Kernel.is_mac? and File.exist?(File.join(USERPATH, 'tools', 'mac'))
          shell_command = "open tools/mac/#{split_command[1]}.app --args #{split_command[2..-1].join(' ')}"
        else
          shell_command = "RUBYW tools/#{split_command[1]} #{split_command[2..-1].join(' ')}"
        end
      elsif split_command[0] == 'LAUNCH_TERMINAL'
        if Kernel.is_mac?
          shell_command = "osascript -e 'tell application \"Terminal\" to do script \"cd #{File.expand_path(USERPATH)} && ruby tools/#{split_command[1]} #{split_command[2..-1].join(' ')}\"' -e 'return'"
        elsif Kernel.is_windows?
          shell_command = "start ruby tools/#{split_command[1]} #{split_command[2..-1].join(' ')}"
        else
          shell_command = "gnome-terminal -e \"ruby tools/#{split_command[1]} #{split_command[2..-1].join(' ')}\""
        end
      end
      shell_command.gsub!('RUBYW', rubyw_sub)
      shell_command
    end

  end # class LauncherConfig

end # module Cosmos
