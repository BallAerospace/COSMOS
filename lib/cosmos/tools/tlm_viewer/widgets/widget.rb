# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/dialogs/tlm_details_dialog'
require 'cosmos/gui/dialogs/tlm_edit_dialog'
require 'cosmos/gui/dialogs/tlm_graph_dialog'

module Cosmos

  # The Widget module must be included by all widget classes used to display
  # telemetry by COSMOS. It provides methods to process settings applied in
  # Telemetry Viewer screen definitions as well as adding a context menu for
  # all widgets which take a value.
  module Widget
    attr_accessor :value_type
    attr_accessor :limits_state
    attr_accessor :settings
    attr_accessor :polling_period
    attr_accessor :screen

    attr_reader :target_name
    attr_reader :packet_name
    attr_reader :item_name
    attr_reader :item
    attr_reader :packet
    attr_reader :limits_set
    attr_reader :value

    def initialize(target_name = nil, packet_name = nil, item_name = nil, value_type = :CONVERTED, *args)
      super(*args)
      @target_name = ConfigParser.handle_nil(target_name)
      @packet_name = ConfigParser.handle_nil(packet_name)
      @item_name = ConfigParser.handle_nil(item_name)
      @item = nil
      if @item_name
        if @target_name == 'LOCAL' and @packet_name == 'LOCAL'
          @packet = nil
          @item = nil
        else
          @packet, @item = System.telemetry.packet_and_item(@target_name, @packet_name, @item_name)
        end
      end
      if value_type
        @value_type = value_type.to_s.upcase.to_sym
        Kernel::raise "Unknown value type #{@value_type} given to #{self.class}" unless [:RAW, :CONVERTED, :FORMATTED, :WITH_UNITS].include?(@value_type)
      else
        raise "Nil value type given to #{self.class}" if @item_name
        @value_type = nil
      end
      @value = nil
      @limits_state = nil
      @limits_set = :DEFAULT
      @settings = {'RAW'=>['']}
      @polling_period = nil
      @screen = nil
      @dialogs = []

      if self.is_a? Qt::Widget
        setToolTip(get_tooltip_text())
      end

      if self.class.takes_value? and self.kind_of?(Qt::Widget)
        setContextMenuPolicy(Qt::CustomContextMenu)
        connect(SIGNAL('customContextMenuRequested(const QPoint&)')) do
          context_menu()
        end
      end
    end

    module ClassMethods
      def layout_manager?
        return false
      end

      def takes_value?
        return false
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    def shutdown
      # Normally do nothing
    end

    # This is called for widgets without values in case they need
    # some form of periodic update
    def update_widget
      # Normally do nothing
    end

    # This is called for widgets that take a value periodically
    def value=(value)
      @value = value
    end

    def limits_set=(limits_set)
      if limits_set.to_s.intern != @limits_set
        @limits_set = limits_set.to_s.intern
        if self.is_a? Qt::Widget
          setToolTip(get_tooltip_text())
        end
      end
    end

    def get_tooltip_text
      tooltip_text = ''
      if @item
        if @item.limits.values
          limits = @item.limits.values[@limits_set]
          limits = @item.limits.values[:DEFAULT] unless limits
          if limits
            red_low = limits[0]
            yellow_low = limits[1]
            yellow_high = limits[2]
            red_high = limits[3]
            green_low = limits[4]
            green_high = limits[5]
            if green_low and green_high
              tooltip_text = "#{@target_name} #{@packet_name} #{@item_name}\n#{@item.description}\nRed High Limit = #{red_high}\nYellow High Limit = #{yellow_high}\nGreen High Limit = #{green_high}\nGreen Low Limit = #{green_low}\nYellow Low Limit = #{yellow_low}\nRed Low Limit = #{red_low}"
            else
              tooltip_text = "#{@target_name} #{@packet_name} #{@item_name}\n#{@item.description}\nRed High Limit = #{red_high}\nYellow High Limit = #{yellow_high}\nYellow Low Limit = #{yellow_low}\nRed Low Limit = #{red_low}"
            end
          else
            tooltip_text = "#{@target_name} #{@packet_name} #{@item_name}\n#{@item.description}"
          end
        else
          tooltip_text = "#{@target_name} #{@packet_name} #{@item_name}\n#{@item.description}"
        end
      end
      return tooltip_text
    end

    def set_setting(setting_name, setting_values)
      if setting_name.upcase == 'RAW'
        @settings['RAW'] = [@settings['RAW'][0] + setting_values[0]]
      else
        @settings[setting_name.to_s.upcase] = setting_values
      end
    end

    def set_subsetting(widget_index, setting_name, setting_values)
      # Only Multi-Widgets have subsettings - Ignore
    end

    def process_settings
      sheet = []
      @settings.each do |setting_name, setting_values|
        case setting_name
        when 'TEXTALIGN'
          sheet << "qproperty-alignment:Align#{setting_values[0].capitalize}"
        when 'PADDING'
          sheet << "padding:#{setting_values[0]}"
        when 'MARGIN'
          sheet << "margin:#{setting_values[0]}"
        when 'BACKCOLOR'
          case setting_values.size
          when 1 # color name
            sheet << "background-color:#{setting_values[0]}"
          when 3 # RGB values
            sheet << "background-color:rgb(#{setting_values[0].to_i},#{setting_values[1].to_i},#{setting_values[2].to_i})"
          end
        when 'TEXTCOLOR'
          case setting_values.size
          when 1 # color name
            sheet << "color:#{setting_values[0]}"
          when 3 # RGB values
            sheet << "color:rgb(#{setting_values[0].to_i},#{setting_values[1].to_i},#{setting_values[2].to_i})"
          end
        when 'BORDERCOLOR'
          # Setting the color requires a defined width and style
          sheet << "border-width:1px"
          sheet << "border-style:solid"
          case setting_values.size
          when 1 # color name
            sheet << "border-color:#{setting_values[0]}"
          when 3 # RGB values
            sheet << "border-color:rgb(#{setting_values[0].to_i}, #{setting_values[1].to_i}, #{setting_values[2].to_i})"
          end
        when 'WIDTH'
          sheet << "min-width:#{setting_values[0].to_i}px"
          sheet << "max-width:#{setting_values[0].to_i}px"
        when 'HEIGHT'
          sheet << "min-height:#{setting_values[0].to_i}px"
          sheet << "max-height:#{setting_values[0].to_i}px"
        when 'RAW'
          next if setting_values[0] == '' # ignore the blank default
          sheet << setting_values[0]
        end
      end
      # Only apply the stylesheet if we have settings to apply and this is a widget (not a layout)
      unless sheet.empty?
        if self.is_a? Qt::Widget
          # Set the object name so we can uniquely assign the stylesheet to it
          setObjectName(self.object_id.to_s)
          setStyleSheet("QWidget##{self.objectName} { #{sheet.join(';')} }")
        elsif parentWidget
          pw = parentWidget
          pw.setObjectName(pw.object_id.to_s)
          pw.setStyleSheet("QWidget##{pw.objectName} { #{sheet.join(';')} }")
        end
      end
    end

    def context_menu
      menu = Qt::Menu.new
      details = Qt::Action.new("Details #{@target_name} #{@packet_name} #{@item_name}", menu)
      details.connect(SIGNAL('triggered()')) do
        if @target_name and @packet_name and @item_name
          if @packet_name.upcase == Telemetry::LATEST_PACKET_NAME
            packets = System.telemetry.latest_packets(@target_name, @item_name)
            offset = 0
            packets.each do |packet|
              dialog = TlmDetailsDialog.new(nil, @target_name, packet.packet_name, @item_name)
              dialog.move(dialog.x + offset, dialog.y + offset)
              @dialogs << dialog
              offset += 30
            end
          else
            @dialogs << TlmDetailsDialog.new(nil, @target_name, @packet_name, @item_name)
          end
        end
      end
      menu.addAction(details)

      edit = Qt::Action.new("Edit #{@target_name} #{@packet_name} #{@item_name}", menu)
      edit.connect(SIGNAL('triggered()')) do
        if @packet_name.upcase != Telemetry::LATEST_PACKET_NAME
          @dialogs << TlmEditDialog.new(self.window, @target_name, @packet_name, @item_name)
        end
      end
      menu.addAction(edit)

      graph = Qt::Action.new("Graph #{@target_name} #{@packet_name} #{@item_name}", menu)
      graph.connect(SIGNAL('triggered()')) do
        TlmGraphDialog.new(self, target_name, packet_name, item_name, @screen.replay_flag.visible)
      end
      menu.addAction(graph)

      point = Qt::Point.new(0,0)
      menu.exec(mapToGlobal(point))
      point.dispose
      menu.dispose
    end

    # Requires the @screen to be set so must not be called in initialize()
    def get_image(image_name)
      return nil unless @screen
      target_screen_dir = File.join(::Cosmos::USERPATH, 'config', 'targets', @screen.original_target_name.upcase, 'screens')

      if File.exist?(File.join(target_screen_dir, image_name))
        return Qt::Image.new(File.join(target_screen_dir, image_name))
      elsif Cosmos.data_path(image_name)
        return Qt::Image.new(Cosmos.data_path(image_name))
      else
        raise "Can't find the file #{image_name} in #{target_screen_dir} or the cosmos data directory."
      end
    end
  end
end
