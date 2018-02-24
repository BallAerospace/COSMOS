# encoding: ascii-8bit

# Copyright 2018 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/qt'
require 'cosmos/io/json_drb_object'

module Cosmos
  class DartMetaFrame < Qt::Widget
    attr_reader :meta_filters
    
    def initialize(parent)
      super(parent)

      @meta_filters = []
      @got_meta_item_names = false

      @layout = Qt::VBoxLayout.new(self)
      @layout.setContentsMargins(0,0,0,0)      

      @groupbox = Qt::GroupBox.new("Meta Filter Selection")
      @vbox = Qt::VBoxLayout.new(@groupbox)
      @hbox1 = Qt::HBoxLayout.new
      @label = Qt::Label.new("Meta Filters: ")
      @hbox1.addWidget(@label)
      @meta_filters_text = Qt::LineEdit.new
      @meta_filters_text.setReadOnly(true)
      @hbox1.addWidget(@meta_filters_text)
      @clear_button = Qt::PushButton.new("Clear")
      @hbox1.addWidget(@clear_button)
      @clear_button.connect(SIGNAL('clicked()')) do
        @meta_filters = []
        @meta_filters_text.text = ""
        update_meta_item_names()        
      end
      @vbox.addLayout(@hbox1)

      @hbox2 = Qt::HBoxLayout.new
      @meta_item_name = Qt::ComboBox.new
      @meta_item_name.setMinimumWidth(200)
      @meta_item_name.setMaxVisibleItems(6)
      @hbox2.addWidget(@meta_item_name)
      @comparison = Qt::ComboBox.new
      @comparison.addItem("==")
      @comparison.addItem("!=")
      @comparison.addItem(">")
      @comparison.addItem(">=")
      @comparison.addItem("<")
      @comparison.addItem("<=")
      @comparison.setMaxVisibleItems(6)
      @hbox2.addWidget(@comparison)
      @filter_value = Qt::LineEdit.new
      @hbox2.addWidget(@filter_value)
      @add_button = Qt::PushButton.new("Add Filter")
      @add_button.connect(SIGNAL('clicked()')) do
        filter_value = @filter_value.text
        if filter_value.to_s.strip.length > 0
          if filter_value.index(" ")
            if filter_value.index('"')
              @meta_filters << "#{@meta_item_name.text} #{@comparison.text} '#{@filter_value.text}'"
            else
              @meta_filters << "#{@meta_item_name.text} #{@comparison.text} \"#{@filter_value.text}\""
            end
          else
            @meta_filters << "#{@meta_item_name.text} #{@comparison.text} #{@filter_value.text}"
          end
        else
          @meta_filters << "#{@meta_item_name.text} #{@comparison.text} ''"
        end
        @meta_filters_text.text = @meta_filters.to_s[1..-2]
      end
      @hbox2.addWidget(@add_button)
      @vbox.addLayout(@hbox2)
      @layout.addWidget(@groupbox)

      setLayout(@layout)

      @resize_timer = Qt::Timer.new
      @resize_timer.connect(SIGNAL('timeout()')) { update_meta_item_names() }      
      @resize_timer.start(100)
    end

    protected

    def update_meta_item_names
      if !@got_meta_item_names and !@update_thread
        @update_thread = Thread.new do
          begin
            server = JsonDRbObject.new(System.connect_hosts['DART_DECOM'], System.ports['DART_DECOM'])
            item_names = server.item_names("SYSTEM", "META")
            Qt.execute_in_main_thread do
              @meta_item_name.clear
              item_names.each do |item|
                @meta_item_name.addItem(item)
              end
            end
            @got_meta_item_names = true
          ensure
            @update_thread = nil
            server.disconnect if defined? server
          end
        end
      end
    end
  end
end
