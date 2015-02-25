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

  # Implements the status tab in the Command and Telemetry Server GUI
  class StatusTab

    # Create the status tab and add it to the tab_widget
    #
    # @param tab_widget [Qt::TabWidget] The tab widget to add the tab to
    def populate(tab_widget)
      scroll = Qt::ScrollArea.new
      widget = Qt::Widget.new
      layout = Qt::VBoxLayout.new(widget)

      populate_limits_status(layout)
      populate_api_status(layout)
      populate_system_status(layout)
      populate_background_status(layout)

      # Set the scroll area widget last now that all the items have been layed out
      scroll.setWidget(widget)
      tab_widget.addTab(scroll, "Status")
    end

    # Update the status tab in the GUI
    def update
      update_limits_set()
      update_api_status()
      update_system_status()
      update_background_task_status()
    end

    private

    def populate_limits_status(layout)
      limits = Qt::GroupBox.new(Qt::Object.tr("Limits Status"))
      limits_layout = Qt::FormLayout.new(limits)
      current_limits_set = System.limits_set.to_s

      known_limits_sets = System.limits.sets
      known_limits_sets = known_limits_sets.map {|x| x.to_s}.sort
      current_index = known_limits_sets.index(current_limits_set.to_s)

      @limits_set_combo = Qt::ComboBox.new
      limits_layout.addRow("Limits Set:", @limits_set_combo)
      layout.addWidget(limits)

      known_limits_sets.sort.each do |limits_set|
        @limits_set_combo.addItem(limits_set.to_s)
      end
      @limits_set_combo.setMaxVisibleItems(6)
      @limits_set_combo.setCurrentIndex(current_index)
      # Only connect to the signal that is sent when the user chooses an item.
      # If the limits set is changed programatically the code in
      # handle_status_tab will pick up the change.
      @limits_set_combo.connect(SIGNAL('activated(int)')) do
        selected_limits_set = @limits_set_combo.currentText
        if selected_limits_set
          System.limits_set = selected_limits_set.intern if System.limits_set != selected_limits_set.intern
        end
      end
    end

    def populate_api_status(layout)
      if CmdTlmServer.json_drb
        @previous_request_count = CmdTlmServer.json_drb.request_count
      else
        @previous_request_count = 0
      end

      api = Qt::GroupBox.new(Qt::Object.tr("API Status"))
      api_layout = Qt::VBoxLayout.new(api)
      @api_table = Qt::TableWidget.new()
      @api_table.verticalHeader.hide()
      @api_table.setRowCount(1)
      @api_table.setColumnCount(6)
      @api_table.setHorizontalHeaderLabels(["Port", "Num Clients", "Requests", "Requests/Sec", "Avg Request Time", "Estimated Utilization"])

      @api_table.setItem(0, 0, Qt::TableWidgetItem.new(Qt::Object.tr(System.ports['CTS_API'].to_s)))
      item0 = Qt::TableWidgetItem.new(Qt::Object.tr(CmdTlmServer.json_drb.num_clients.to_s))
      item0.setTextAlignment(Qt::AlignCenter)
      @api_table.setItem(0, 1, item0)
      item = Qt::TableWidgetItem.new(Qt::Object.tr(@previous_request_count.to_s))
      item.setTextAlignment(Qt::AlignCenter)
      @api_table.setItem(0, 2, item)
      item2 = Qt::TableWidgetItem.new("0.0")
      item2.setTextAlignment(Qt::AlignCenter)
      @api_table.setItem(0, 3, item2)
      item3 = Qt::TableWidgetItem.new("0.0")
      item3.setTextAlignment(Qt::AlignCenter)
      @api_table.setItem(0, 4, item3)
      item4 = Qt::TableWidgetItem.new("0.0")
      item4.setTextAlignment(Qt::AlignCenter)
      @api_table.setItem(0, 5, item4)
      @api_table.displayFullSize
      api_layout.addWidget(@api_table)
      layout.addWidget(api)
    end

    def populate_system_status(layout)
      system = Qt::GroupBox.new(Qt::Object.tr("System Status"))
      system_layout = Qt::VBoxLayout.new(system)
      @system_table = Qt::TableWidget.new()
      @system_table.verticalHeader.hide()
      @system_table.setRowCount(1)
      @system_table.setColumnCount(4)
      @system_table.setHorizontalHeaderLabels(["Threads", "Total Objs", "Free Objs", "Allocated Objs"])

      item0 = Qt::TableWidgetItem.new("0")
      item0.setTextAlignment(Qt::AlignCenter)
      @system_table.setItem(0, 0, item0)
      item1 = Qt::TableWidgetItem.new("0.0")
      item1.setTextAlignment(Qt::AlignCenter)
      @system_table.setItem(0, 1, item1)
      item2 = Qt::TableWidgetItem.new("0.0")
      item2.setTextAlignment(Qt::AlignCenter)
      @system_table.setItem(0, 2, item2)
      item3 = Qt::TableWidgetItem.new("0.0")
      item3.setTextAlignment(Qt::AlignCenter)
      @system_table.setItem(0, 3, item3)
      @system_table.displayFullSize
      system_layout.addWidget(@system_table)
      layout.addWidget(system)
    end

    def populate_background_status(layout)
      background_tasks_groupbox = Qt::GroupBox.new(Qt::Object.tr("Background Tasks"))
      background_tasks_layout = Qt::VBoxLayout.new(background_tasks_groupbox)
      @background_tasks_table = Qt::TableWidget.new()
      @background_tasks_table.verticalHeader.hide()
      @background_tasks_table.setRowCount(CmdTlmServer.background_tasks.all.length)
      @background_tasks_table.setColumnCount(3)
      @background_tasks_table.setHorizontalHeaderLabels(["Name", "State", "Status"])

      background_tasks = CmdTlmServer.background_tasks.all
      if background_tasks.length > 0
        row = 0
        background_tasks.each_with_index do |background_task, index|
          background_task_name = background_task.name
          background_task_name = "Background Task ##{index + 1}" unless background_task_name
          background_task_name_widget = Qt::TableWidgetItem.new(background_task_name)
          background_task_name_widget.setTextAlignment(Qt::AlignCenter)
          @background_tasks_table.setItem(row, 0, background_task_name_widget)
          if background_task.thread
            status = background_task.thread.status
            status = 'complete' if status == false
            background_task_state_widget = Qt::TableWidgetItem.new(status.to_s)
          else
            background_task_state_widget = Qt::TableWidgetItem.new('no thread')
          end
          background_task_state_widget.setTextAlignment(Qt::AlignCenter)
          background_task_state_widget.setSizeHint(Qt::Size.new(80, 30))
          @background_tasks_table.setItem(row, 1, background_task_state_widget)
          background_task_status_widget = Qt::TableWidgetItem.new(background_task.status.to_s)
          background_task_status_widget.setTextAlignment(Qt::AlignCenter)
          background_task_status_widget.setSizeHint(Qt::Size.new(500, 30))
          @background_tasks_table.setItem(row, 2, background_task_status_widget)

          row += 1
        end
      end
      @background_tasks_table.displayFullSize
      background_tasks_layout.addWidget(@background_tasks_table)
      layout.addWidget(background_tasks_groupbox)
    end

    # Update the current limits set in the GUI
    def update_limits_set
      current_limits_set = System.limits_set.to_s
      if @limits_set_combo.currentText != current_limits_set
        known_limits_sets = System.limits.sets
        known_limits_sets = known_limits_sets.map {|x| x.to_s}.sort
        current_index = known_limits_sets.index(current_limits_set.to_s)
        @limits_set_combo.clear
        known_limits_sets.sort.each do |limits_set|
          @limits_set_combo.addItem(limits_set.to_s)
        end
        @limits_set_combo.setCurrentIndex(current_index)
      end
    end

    # Update the API statistics in the GUI
    def update_api_status
      if CmdTlmServer.json_drb
        @api_table.item(0,1).setText(CmdTlmServer.json_drb.num_clients.to_s)
        @api_table.item(0,2).setText(CmdTlmServer.json_drb.request_count.to_s)
        request_count = CmdTlmServer.json_drb.request_count
        requests_per_second = request_count - @previous_request_count
        @api_table.item(0,3).setText(requests_per_second.to_s)
        @previous_request_count = request_count
        average_request_time = CmdTlmServer.json_drb.average_request_time
        @api_table.item(0,4).setText(sprintf("%0.6f s", average_request_time))
        estimated_utilization = requests_per_second * average_request_time * 100.0
        @api_table.item(0,5).setText(sprintf("%0.2f %", estimated_utilization))
      end
    end

    # Update the Ruby system statistics in the GUI
    def update_system_status
      @system_table.item(0,0).setText(Thread.list.length.to_s)
      objs = ObjectSpace.count_objects
      @system_table.item(0,1).setText(objs[:TOTAL].to_s)
      @system_table.item(0,2).setText(objs[:FREE].to_s)
      total = 0
      objs.each do |key, val|
        next if key == :TOTAL || key == :FREE
        total += val
      end
      @system_table.item(0,3).setText(total.to_s)
    end

    # Update the background task status in the GUI
    def update_background_task_status
      background_tasks = CmdTlmServer.background_tasks.all
      if background_tasks.length > 0
        row = 0
        background_tasks.each_with_index do |background_task, index|
          if background_task.thread
            status = background_task.thread.status
            status = 'complete' if status == false
            @background_tasks_table.item(row, 1).setText(status.to_s)
          else
            @background_tasks_table.item(row, 1).setText('no thread')
          end
          @background_tasks_table.item(row, 2).setText(background_task.status.to_s)
          row += 1
        end
      end
    end

  end
end # module Cosmos
