# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/qt'

module Cosmos

  # Implements the interfaces and routers tabs in the Command and Telemetry Server GUI
  class InterfacesTab
    INTERFACES = 'Interfaces'
    ROUTERS = 'Routers'
    ALIGN_CENTER = Qt::AlignCenter

    def initialize
      @interfaces_table = {}
    end

    # Create the interfaces tab and add it to the tab_widget
    #
    # @param tab_widget [Qt::TabWidget] The tab widget to add the tab to
    def populate_interfaces(tab_widget)
      populate(INTERFACES, CmdTlmServer.interfaces, tab_widget)
    end

    # Create the routers tab and add it to the tab_widget
    #
    # @param tab_widget [Qt::TabWidget] The tab widget to add the tab to
    def populate_routers(tab_widget)
      populate(ROUTERS, CmdTlmServer.routers, tab_widget)
    end

    # Update the interfaces or routers tab
    #
    # @param name [String] Must be Interfaces or Routers
    def update(name)
      if name == ROUTERS
        interfaces = CmdTlmServer.routers
      else
        interfaces = CmdTlmServer.interfaces
      end
      row = 0
      interfaces.all.each do |interface_name, interface|
        button = @interfaces_table[name].cellWidget(row,1)
        state = @interfaces_table[name].item(row,2)
        if interface.connected? and interface.thread
          button.setText('Disconnect')
          button.setDisabled(true) if interface.disable_disconnect
          state.setText('true')
          state.textColor = Cosmos::GREEN
        elsif interface.thread
          button.text = 'Cancel Connect'
          button.setDisabled(false)
          state.setText('attempting')
          state.textColor = Cosmos::RED
        elsif interface.connected?
          button.setText('Error')
          button.setDisabled(false)
          state.setText('error')
          state.textColor = Cosmos::RED
        else
          button.setText('Connect')
          button.setDisabled(false)
          state.setText('false')
          state.textColor = Cosmos::BLACK
        end
        @interfaces_table[name].item(row,3).setText(interface.num_clients.to_s)
        @interfaces_table[name].item(row,4).setText(interface.write_queue_size.to_s)
        @interfaces_table[name].item(row,5).setText(interface.read_queue_size.to_s)
        @interfaces_table[name].item(row,6).setText(interface.bytes_written.to_s)
        @interfaces_table[name].item(row,7).setText(interface.bytes_read.to_s)
        if name == ROUTERS
          @interfaces_table[name].item(row,8).setText(interface.read_count.to_s)
          @interfaces_table[name].item(row,9).setText(interface.write_count.to_s)
        else
          @interfaces_table[name].item(row,8).setText(interface.write_count.to_s)
          @interfaces_table[name].item(row,9).setText(interface.read_count.to_s)
        end
        row += 1
      end
    end

    private

    def populate(name, interfaces, tab_widget)
      return if interfaces.all.empty?

      scroll = Qt::ScrollArea.new
      scroll.setMinimumSize(800, 150)
      widget = Qt::Widget.new
      layout = Qt::VBoxLayout.new(widget)
      # Since the layout will be inside a scroll area make sure it respects the sizes we set
      layout.setSizeConstraint(Qt::Layout::SetMinAndMaxSize)

      interfaces_table = Qt::TableWidget.new()
      interfaces_table.verticalHeader.hide()
      interfaces_table.setRowCount(interfaces.all.length)
      interfaces_table.setColumnCount(10)
      if name == ROUTERS
        interfaces_table.setHorizontalHeaderLabels(["Router", "Connect/Disconnect", "Connected?", "Clients", "Tx Q Size", "Rx Q Size", "   Bytes Tx   ", "   Bytes Rx   ", "  Cmd Pkts  ", "  Tlm Pkts  "])
      else
        interfaces_table.setHorizontalHeaderLabels(["Interface", "Connect/Disconnect", "Connected?", "Clients", "Tx Q Size", "Rx Q Size", "   Bytes Tx   ", "   Bytes Rx   ", "  Cmd Pkts  ", "  Tlm Pkts  "])
      end

      populate_interface_table(name, interfaces, interfaces_table)
      interfaces_table.displayFullSize

      layout.addWidget(interfaces_table)
      scroll.setWidget(widget)
      @interfaces_table[name] = interfaces_table
      tab_widget.addTab(scroll, name)
    end

    def populate_interface_table(name, interfaces, interfaces_table)
      row = 0
      interfaces.all.each do |interface_name, interface|
        item = Qt::TableWidgetItem.new(Qt::Object.tr(interface_name))
        item.setTextAlignment(ALIGN_CENTER)
        interfaces_table.setItem(row, 0, item)
        interfaces_table.setCellWidget(row, 1, create_button(name, interface, interface_name))
        interfaces_table.setItem(row, 2, create_state(interface))

        index = 3
        [interface.num_clients, interface.write_queue_size, interface.read_queue_size,
          interface.bytes_written, interface.bytes_read,
          interface.write_count, interface.read_count].each do |val|

          item = Qt::TableWidgetItem.new(val.to_s)#Qt::Object.tr(val.to_s))
          item.setTextAlignment(ALIGN_CENTER)
          interfaces_table.setItem(row, index, item)
          index += 1
        end
        row += 1
      end
    end

    def create_button(name, interface, interface_name)
      if interface.connected? and interface.thread
        button_text = 'Disconnect'
      elsif interface.thread
        button_text = 'Cancel Connect'
      elsif interface.connected?
        button_text = 'Error'
      else
        button_text = 'Connect'
      end
      button = Qt::PushButton.new(button_text)
      if name == ROUTERS
        button.connect(SIGNAL('clicked()')) do
          if interface.thread
            Logger.info "User disconnecting router #{interface_name}"
            CmdTlmServer.instance.disconnect_router(interface_name)
          else
            Logger.info "User connecting router #{interface_name}"
            CmdTlmServer.instance.connect_router(interface_name)
          end
        end
      else
        button.connect(SIGNAL('clicked()')) do
          if interface.thread
            Logger.info "User disconnecting interface #{interface_name}"
            CmdTlmServer.instance.disconnect_interface(interface_name)
          else
            Logger.info "User connecting interface #{interface_name}"
            CmdTlmServer.instance.connect_interface(interface_name)
          end
        end
      end
      button.setDisabled(true) if interface.disable_disconnect
      button
    end

    def create_state(interface)
      state = Qt::TableWidgetItem.new
      if interface.connected? and interface.thread
        state.setText('true')
        state.textColor = Cosmos::GREEN
      elsif interface.thread
        state.setText('attempting')
        state.textColor = Cosmos::YELLOW
      elsif interface.connected?
        state.setText('error')
        state.textColor = Cosmos::RED
      else
        state.setText('false')
        state.textColor = Cosmos::BLACK
      end
      state.setTextAlignment(Qt::AlignCenter)
      state
    end

  end
end # module Cosmos
