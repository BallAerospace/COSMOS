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

  # Implements the targets tab in the Command and Telemetry Server GUI
  class TargetsTab

    # Create the targets tab and add it to the tab_widget
    #
    # @param tab_widget [Qt::TabWidget] The tab widget to add the tab to
    def populate(tab_widget)
      num_targets = System.targets.length
      if num_targets > 0
        return if num_targets == 1 and System.targets['SYSTEM']
        num_targets -= 1 if System.targets['SYSTEM']

        scroll = Qt::ScrollArea.new
        widget = Qt::Widget.new
        layout = Qt::VBoxLayout.new(widget)
        # Since the layout will be inside a scroll area make sure it respects the sizes we set
        layout.setSizeConstraint(Qt::Layout::SetMinAndMaxSize)

        @targets_table = Qt::TableWidget.new()
        @targets_table.verticalHeader.hide()
        @targets_table.setRowCount(num_targets)
        @targets_table.setColumnCount(4)
        @targets_table.setHorizontalHeaderLabels(["Target Name", "Interface", "Command Count", "Telemetry Count"])

        populate_targets_table()

        @targets_table.displayFullSize

        layout.addWidget(@targets_table)
        scroll.setWidget(widget)
        tab_widget.addTab(scroll, "Targets")
      end
    end

    # Update the targets tab gui
    def update
      row = 0
      System.targets.sort.each do |target_name, target|
        next if target_name == 'SYSTEM'
        @targets_table.item(row,2).setText(target.cmd_cnt.to_s)
        @targets_table.item(row,3).setText(target.tlm_cnt.to_s)
        row += 1
      end
    end

    private

    def populate_targets_table
      row = 0
      System.targets.sort.each do |target_name, target|
        next if target_name == 'SYSTEM'
        target_name_widget = Qt::TableWidgetItem.new(Qt::Object.tr(target_name))
        target_name_widget.setTextAlignment(Qt::AlignCenter)
        @targets_table.setItem(row, 0, target_name_widget)
        if target.interface
          interface_name_widget = Qt::TableWidgetItem.new(Qt::Object.tr(target.interface.name.to_s))
        else
          interface_name_widget = Qt::TableWidgetItem.new(Qt::Object.tr(''))
        end
        interface_name_widget.setTextAlignment(Qt::AlignCenter)
        @targets_table.setItem(row, 1, interface_name_widget)
        cmd_cnt = Qt::TableWidgetItem.new(Qt::Object.tr(target.cmd_cnt.to_s))
        cmd_cnt.setTextAlignment(Qt::AlignCenter)
        @targets_table.setItem(row, 2, cmd_cnt)

        tlm_cnt = Qt::TableWidgetItem.new(Qt::Object.tr(target.tlm_cnt.to_s))
        tlm_cnt.setTextAlignment(Qt::AlignCenter)
        @targets_table.setItem(row, 3, tlm_cnt)

        row += 1
      end
    end

  end
end # module Cosmos
