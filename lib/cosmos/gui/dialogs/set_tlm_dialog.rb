# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/qt'
require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server'
require 'cosmos/tools/cmd_tlm_server/api'

module Cosmos

  class SetTlmDialog < Qt::Dialog
    IGNORED_ITEMS = ['RECEIVED_TIMESECONDS', 'RECEIVED_TIMEFORMATTED', 'RECEIVED_COUNT']

    attr_reader :error_label
    attr_accessor :current_item_name

    def initialize(parent, title, done_label, cancel_label, target_name, packet_name, packet = nil)
      super(parent, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
      @target_name = target_name
      @packet_name = packet_name
      @current_item_name = nil

      extend Api if CmdTlmServer.instance

      if !packet
        @items = get_tlm_packet(@target_name, @packet_name)
      else
        @items = packet.read_all_with_limits_states
      end
      @items.delete_if {|item_name, _, _| ['RECEIVED_TIMESECONDS', 'RECEIVED_TIMEFORMATTED', 'RECEIVED_COUNT'].include?(item_name)}

      setWindowTitle(title)
      Cosmos.load_cosmos_icon

      layout = Qt::VBoxLayout.new
      @tab_book = Qt::TabWidget.new
      values_layout = Qt::FormLayout.new
      widget = Qt::Widget.new
      widget.layout = values_layout
      page_count = 1
      @tab_book.addTab(widget, "Page #{page_count}")
      @editors = []
      @items.each do |item_name, item_value, _|
        _, item = System.telemetry.packet_and_item(@target_name, @packet_name, item_name)
        if item.states
          @editors << Qt::ComboBox.new
          @editors[-1].setSizeAdjustPolicy(Qt::ComboBox::AdjustToContents)
          current_index = 0
          index = 0
          item.states.each do |state_name, state_value|
            @editors[-1].addItem(state_name)
            current_index = index if state_name == item_value
            index += 1
          end
          if item.states.length > 20
            @editors[-1].setMaxVisibleItems(20)
          else
            @editors[-1].setMaxVisibleItems(item.states.length)
          end
          @editors[-1].setCurrentIndex(current_index)
        else
          @editors << Qt::LineEdit.new
          @editors[-1].text = item_value.to_s
        end
        values_layout.addRow(item_name, @editors[-1])
        if ((@editors.length % 10) == 0 and @items.length > @editors.length)
          values_layout = Qt::FormLayout.new
          widget = Qt::Widget.new
          widget.layout = values_layout
          page_count += 1
          @tab_book.addTab(widget, "Page #{page_count}")
        end
      end

      layout.addWidget(@tab_book)
      @error_label = Qt::Label.new('')
      layout.addWidget(@error_label)

      button_layout = Qt::HBoxLayout.new
      # Create Done Button
      done_button = Qt::PushButton.new(done_label)
      connect(done_button, SIGNAL('clicked()'), self, SLOT('accept()'))
      button_layout.addWidget(done_button)

      # Create Cancel Button
      cancel_button = Qt::PushButton.new(cancel_label)
      connect(cancel_button, SIGNAL('clicked()'), self, SLOT('reject()'))
      button_layout.addWidget(cancel_button)
      layout.addLayout(button_layout)

      self.setLayout(layout)
    end

    def set_items
      index = 0
      @items.each do |item_name, _, _|
        @current_item_name = item_name
        set_tlm(@target_name, @packet_name, item_name, @editors[index].text)
        index += 1
      end
    end

    def self.execute(parent, title, done_label, cancel_label, target_name, packet_name, packet = nil)
      dialog = self.new(parent, title, done_label, cancel_label, target_name, packet_name, packet)
      begin
        dialog.raise
        if dialog.exec == Qt::Dialog::Accepted
          dialog.set_items
          result = true
        else
          result = false
        end
      rescue => err
        dialog.error_label.setText("Error Setting #{dialog.current_item_name}: " + err.message)
        retry
      ensure
        dialog.dispose
      end
      result
    end

  end # class SetTlmDialog

end # module Cosmos
