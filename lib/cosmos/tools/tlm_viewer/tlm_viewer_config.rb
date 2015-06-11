# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'

module Cosmos

  class TlmViewerConfig

    class ScreenInfo
      attr_accessor :group
      attr_accessor :target_name
      attr_accessor :original_target_name
      attr_accessor :name
      attr_accessor :filename
      attr_accessor :x_pos
      attr_accessor :y_pos
      attr_accessor :substitute
      attr_accessor :force_substitute
      attr_accessor :screen
      attr_accessor :show_on_startup
      attr_accessor :items
      attr_accessor :invalid_items

      def initialize(group, target_name, name, filename, x_pos, y_pos)
        @group = group
        @target_name = target_name.upcase
        @original_target_name = nil
        @name = name.upcase
        @name = "#{@target_name} #{@name}" if group
        @filename = filename
        @x_pos = x_pos
        @y_pos = y_pos
        @substitute = nil
        @force_substitute = false
        @screen = nil
        @show_on_startup = false
        @items = []
        @invalid_items = []
      end

      def full_name
        @group ? @name : "#{@target_name} #{@name}"
      end

      def read_items
        @items = []
        @invalid_items = []
        begin
          parser = ConfigParser.new
          parser.parse_file(@filename) do |keyword, parameters|
            if keyword
              case keyword
              when 'SCREEN', 'END', 'SETTING', 'SUBSETTING', 'GLOBAL_SETTING', 'GLOBAL_SUBSETTING'
                # Do nothing
              else
                if keyword == 'NAMED_WIDGET'
                  keyword = parameters[1].to_s.upcase
                  parameters = parameters[2..-1]
                end

                klass = Cosmos.require_class(keyword.downcase + '_widget')
                if klass.takes_value?
                  begin
                    if @substitute and (@original_target_name == parameters[0].to_s.upcase or @force_substitute)
                      System.telemetry.packet_and_item(@substitute, parameters[1], parameters[2])
                      @items << "#{@substitute} #{parameters[1]} #{parameters[2]}".upcase
                    else
                      System.telemetry.packet_and_item(*parameters[0..2])
                      @items << "#{parameters[0]} #{parameters[1]} #{parameters[2]}".upcase
                    end
                  rescue
                    @invalid_items << "#{parameters[0]} #{parameters[1]} #{parameters[2]}".upcase
                    next
                  end
                end
              end # case keyword
            end # if keyword
          end # parser.parse_file
        rescue Exception
          # Oh well - Bad Screen
        end
      end
    end

    attr_accessor :columns
    attr_accessor :screen_infos
    attr_accessor :filename
    attr_accessor :completion_list
    attr_accessor :tlm_to_screen_mapping

    def initialize(filename = nil)
      # Handle nil filename
      filename = File.join(Cosmos::USERPATH, 'config', 'tools', 'tlm_viewer', 'tlm_viewer.txt') unless filename
      @filename = filename

      # Ensure the file exists
      raise "Telemetry Viewer configuration file #{filename} does not exist" unless test ?f, filename

      # Initialize instance variables
      @columns = []
      @columns << {}
      @screen_infos = {}

      # Process File
      @current_column = @columns[0]
      @current_target = nil
      @current_screens = nil
      @current_screen_info = nil
      @current_group = nil
      parser = ConfigParser.new
      parser.parse_file(filename) do |keyword, parameters|
        case keyword

        when 'NEW_COLUMN'
          @columns << {}
          @current_column = @columns[-1]

        when 'AUTO_TARGETS'
          parser.verify_num_parameters(0, 0, 'AUTO_TARGETS')
          System.targets.each do |target_name, target|
            screen_dir = File.join(target.dir, 'screens')
            if File.exist?(screen_dir) and num_screens(screen_dir) > 0
              start_target(target.name, parser)
              auto_screens()
            end
          end

        when 'AUTO_TARGET'
          parser.verify_num_parameters(1, 1, 'AUTO_TARGET <Target Name>')
          target_name = parameters[0].upcase
          target = System.targets[target_name]
          raise parser.error("Unknown target #{target_name}") unless target
          screen_dir = File.join(target.dir, 'screens')
          if File.exist?(screen_dir) and num_screens(screen_dir) > 0
            start_target(target.name, parser)
            auto_screens()
          end

        when 'TARGET'
          parser.verify_num_parameters(1, 1, 'TARGET <Target Name>')
          target_name = parameters[0].upcase
          start_target(target_name, parser)

        when 'SCREEN'
          raise parser.error("No target defined. SCREEN must follow TARGET.") unless @current_target
          parser.verify_num_parameters(1, 3, 'SCREEN <Filename> <X Position (optional)> <Y Position (optional)>')
          screen_filename = File.join(@current_target.dir, 'screens', parameters[0])
          start_screen(screen_filename, parameters[1], parameters[2])

        when 'SHOW_ON_STARTUP'
          raise parser.error("No screen defined. SHOW_ON_STARTUP must follow SCREEN or GROUP_SCREEN.") unless @current_screen_info
          parser.verify_num_parameters(0, 0, 'SHOW_ON_STARTUP')
          @current_screen_info.show_on_startup = true

        when 'ADD_SHOW_ON_STARTUP'
          parser.verify_num_parameters(2, 4, 'ADD_SHOW_ON_STARTUP <Target Name> <Screen Name> <X Position (optional)> <Y Position (optional)>')
          @current_screen_info = @screen_infos["#{parameters[0]} #{parameters[1]}".upcase]
          raise parser.error("Screen #{parameters[0]} #{parameters[1]} does not exist") unless @current_screen_info
          @current_screen_info.show_on_startup = true
          @current_screen_info.x_pos = parameters[2].to_i if parameters[2]
          @current_screen_info.y_pos = parameters[3].to_i if parameters[3]

        when 'GROUP'
          parser.verify_num_parameters(1, 1, 'GROUP <Group Name>')
          @current_group = parameters[0]
          @current_screens = {}
          @current_column[@current_group] = @current_screens

        when 'GROUP_SCREEN'
          raise parser.error("No group defined. GROUP_SCREEN must follow GROUP.") unless @current_group
          parser.verify_num_parameters(2, 4, 'GROUP_SCREEN <Target Name> <Screen Filename> <X Position (optional)> <Y Position (Optional)>')
          start_target(parameters[0].upcase, parser, @current_group)
          screen_filename = File.join(@current_target.dir, 'screens', parameters[1])
          start_screen(screen_filename, parameters[2], parameters[3])

        else
          # blank config.lines will have a nil keyword and should not raise an exception
          raise parser.error("Unknown keyword '#{keyword}'") if keyword
        end
      end

      build_completion_list()
    end

    def save(filename)
      @filename = filename

      File.open(filename, 'w') do |file|
        @columns.each_with_index do |target_screen_infos, column_index|
          if column_index != 0
            file.puts ''
            file.puts "NEW_COLUMN"
            file.puts ''
          end
          target_screen_infos.each do |target_name, screen_infos|
            file.puts "TARGET \"#{target_name}\""
            screen_infos.each do |screen_name, screen_info|
              # Grab the filename by indexing the full path for 'screens' and going past
              # to capture the filename such as 'status.txt' below
              #   C:/COSMOS/config/targets/TGT/screens/status.txt
              screen_filename = screen_info.filename[(screen_info.filename.index("screens").to_i + 8)..-1]
              string = "  SCREEN"
              string << " \"#{screen_filename}\""
              string << " #{screen_info.x_pos}" if screen_info.x_pos
              string << " #{screen_info.y_pos}" if screen_info.y_pos
              file.puts string
              if screen_info.screen
                file.puts "    SHOW_ON_STARTUP"
              end
            end
            file.puts ""
          end
        end
      end
    end

    def start_target(target_name, parser, group = nil)
      @current_target = System.targets[target_name]
      raise parser.error("Unknown target #{target_name}") unless @current_target
      # If no group was passed setup a new column and screen hash
      unless group
        @current_group = nil
        @current_screens = {}
        @current_column[target_name] = @current_screens
      end
    end

    def start_screen(screen_filename, x_pos = nil, y_pos = nil)
      screen_name = File.basename(screen_filename, '.txt').upcase
      x_pos = x_pos.to_i if x_pos
      y_pos = y_pos.to_i if y_pos

      @current_screen_info = ScreenInfo.new(@current_group, @current_target.name, screen_name, screen_filename, x_pos, y_pos)
      @screen_infos[@current_screen_info.full_name] = @current_screen_info
      @current_screens["#{@current_target.name}_#{screen_name}"] = @current_screen_info
      @current_screen_info.force_substitute = true if @current_target.auto_screen_substitute
      @current_screen_info.original_target_name = @current_target.original_name
      @current_screen_info.substitute = @current_target.name if @current_target.substitute or @current_target.auto_screen_substitute
      @current_screen_info.read_items
    end

    def auto_screens
      @current_group = nil
      screen_dir = File.join(@current_target.dir, 'screens')
      if File.exist?(screen_dir)
        Dir.new(screen_dir).each do |filename|
          if filename[0..0] != '.'
            start_screen(File.join(screen_dir, filename))
          end
        end
      end
    end

    def num_screens(screen_dir)
      count = 0
      Dir.new(screen_dir).each do |filename|
        count += 1 if filename[0..0] != '.'
      end
      count
    end

    def build_completion_list
      @completion_list = []
      @tlm_to_screen_mapping = {}
      total = @screen_infos.length.to_f
      index = 1
      ConfigParser.splash.message = "Building completion list" if ConfigParser.splash
      @screen_infos.each do |name, info|
        ConfigParser.splash.progress = index / total if ConfigParser.splash
        info.items.each do |item|
          @tlm_to_screen_mapping[item] ||= []
          @tlm_to_screen_mapping[item] << name
        end
        @completion_list.concat(info.items)
        index += 1
      end
      @completion_list.uniq!
    end

  end

end # module Cosmos
