# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/utilities/screenshot'
require 'cosmos/gui/line_graph/overview_graph'
require 'cosmos/gui/choosers/integer_chooser'
require 'cosmos/gui/choosers/float_chooser'
require 'cosmos/gui/choosers/string_chooser'
require 'cosmos/tools/tlm_grapher/tabbed_plots_tool/tabbed_plots_plot_editor'
require 'cosmos/tools/tlm_grapher/tabbed_plots_tool/tabbed_plots_data_object_editor'
require 'cosmos/tools/tlm_grapher/plot_gui_objects/linegraph_plot_gui_object'
require 'cosmos/tools/tlm_grapher/plot_gui_objects/xy_plot_gui_object'
require 'cosmos/tools/tlm_grapher/plot_gui_objects/singlexy_plot_gui_object'
require 'cosmos/tools/tlm_grapher/data_object_adders/housekeeping_data_object_adder'
require 'cosmos/tools/tlm_grapher/data_object_adders/xy_data_object_adder'
require 'cosmos/tools/tlm_grapher/data_object_adders/singlexy_data_object_adder'

module Cosmos

  # Implements a widget to display a set of plots in tabs with an overview graph
  class OverviewTabbedPlots < Qt::Widget
    slots 'handle_tab_change(int)'
    slots 'tab_context_menu(const QPoint&)'
    slots 'plot_context_menu(const QPoint&)'
    slots 'data_object_context_menu(const QPoint&)'
    slots 'data_object_moved(const QModelIndex&, int, int, const QModelIndex&, int)'

    # Minimum Overview Points Per Line
    MINIMUM_OVERVIEW_POINTS_PLOTTED = 100

    # Minimum delay between redraws
    MINIMUM_REFRESH_DELAY_MS = 10

    # Accessor to tabbed_plots_config
    attr_accessor :tabbed_plots_config

    # Accessor to adders
    attr_accessor :data_object_adders

    # Callback when right button is released on a tab item
    attr_accessor :tab_item_right_button_release_callback

    # Callback when right button is released on a plot
    attr_accessor :plot_right_button_release_callback

    # Callback when right button is released on a data object
    attr_accessor :data_object_right_button_release_callback

    # Callback when a change to modifies the configuration occurs
    attr_accessor :config_modified_callback

    # Give access to the status bar to other widgets
    attr_reader :status_bar

    def initialize(parent, left_frame, right_frame, status_bar)
      super(parent)
      # Save Constructor Arguments
      @left_frame = left_frame
      @right_frame = right_frame
      @status_bar = status_bar

      # Default startup arguments
      @tabbed_plots_config = nil
      @adder_orientation = Qt::Horizontal

      # Additional instance variables
      @data_object_adders = []
      @tab_item_right_button_release_callback = nil
      @plot_right_button_release_callback = nil
      @data_object_right_button_release_callback = nil
      @config_modified_callback = nil
      @paused = false
      @timeout = nil
      @refresh_rate_ms = (1000.0 / TabbedPlotsConfig::DEFAULT_REFRESH_RATE_HZ).round
      @context_menu_plot = nil
    end # def initialize

    # Startup GUI interaction
    def startup(tabbed_plots_config, adder_orientation, adder_types)
      # Save parameters
      @tabbed_plots_config = tabbed_plots_config
      @adder_orientation = adder_orientation
      @adder_types = adder_types

      # Create GUI elements
      build_right_frame()
      build_left_frame()
      create()
    end # def startup

    # Shutdown GUI interaction
    def shutdown
      # Shutdown drawing timeout
      @timeout.method_missing(:stop) if @timeout

      # Remove GUI elements
      @tabbed_plots_left_frame.removeAll
      @tabbed_plots_right_frame.removeAll
    end # def shutdown

    # Update
    def update
      @data_object_adders.each {|adder| adder.update}
    end

    ###############################################################################
    # Pause / Resume
    ###############################################################################

    # Pause plotting
    def pause
      @paused = true
    end # def pause

    # Resume plotting if paused
    def resume
      @paused = false
    end # def resume

    # Are we paused?
    def paused?
      @paused
    end # def paused?

    ###############################################################################
    # Tab Related Methods
    ###############################################################################

    # Add a new tab
    def add_tab(tab_text = nil)
      unless tab_text
        # If the last tab text is "Tab X" the next tab should be "Tab X+1"
        if (@tabbed_plots_config.tabs.length > 0) &&
          (@tabbed_plots_config.tabs[-1].tab_text =~ /Tab (\d*)/)
          tab_text = "Tab #{$1.to_i + 1}" # $1 is the match from the regexp
        else # Set text to the total number of tabs
          tab_text = "Tab #{@tabbed_plots_config.tabs.length + 1}"
        end
      end
      tab = @tabbed_plots_config.add_tab(tab_text)

      # Create tab item for the tab
      tab_item = Qt::Widget.new
      tab_item.setContextMenuPolicy(Qt::CustomContextMenu)
      connect(tab_item, SIGNAL('customContextMenuRequested(const QPoint&)'), self, SLOT('plot_context_menu(const QPoint&)'))
      tab.gui_item = tab_item

      # Create overall vertical layout manager for tab.
      tab_layout = Qt::VBoxLayout.new()
      tab_item.setLayout(tab_layout)
      tab.gui_frame = tab_layout

      # Create layout manager to hold plots based on number of plots
      layout = Qt::AdaptiveGridLayout.new
      tab_layout.addLayout(layout, 1) # Add with stretch factor 1 to give it priority over everything else
      # Add stretch in case they delete the last plot. This will force the overview graph (which doesn't get deleted)
      # to stay at the bottom of the layout instead of moving
      tab_layout.addStretch()
      tab.gui_layout = layout

      # Add an overview graph to the tab
      @overview_graphs << OverviewGraph.new(self)
      @overview_graphs[-1].callback = method(:overview_graph_callback)
      @overview_graphs[-1].window_size = @seconds_plotted.value
      tab_layout.addWidget(@overview_graphs[-1])

      # Add an initial plot to the tab
      add_plot(-1, false)

      # Add and select the new tab
      index = @tab_book.addTab(tab_item, tab_text)
      @tab_book.setCurrentIndex(index)
      @config_modified_callback.call() if @config_modified_callback
    end # def add_tab

    # Delete a tab - defaults to the current tab
    def delete_tab(tab_index = nil)
      # Select the current tab by default
      tab_index = current_tab_index() unless tab_index

      if tab_index
        # Remove from config
        @tabbed_plots_config.remove_tab(tab_index)

        # Remove knowledge of overview graph
        @overview_graphs.delete_at(tab_index)

        # Remove tab item and frame from tab book
        @tab_book.widget(tab_index).dispose

        # Call tab change callback @tab_book.current is not valid at this point
        if tab_index > (@tabbed_plots_config.tabs.length - 1)
          @tab_book.setCurrentIndex(tab_index - 1)
        else
          @tab_book.setCurrentIndex(tab_index)
        end
      end
      @config_modified_callback.call() if @config_modified_callback
    end # def delete_tab

    # Edit a tab - defaults to the current tab
    def edit_tab(tab_index = nil)
      edited = false

      # Select the current tab by default
      tab_index = current_tab_index() unless tab_index

      if tab_index
        # Get the tab object
        tab = @tabbed_plots_config.tabs[tab_index]

        # Create simple dialog box to edit the tab
        result = Qt::Boolean.new
        string = Qt::InputDialog::getText(self,
                                          "Edit Tab",
                                          "Tab Text:",
                                          Qt::LineEdit::Normal,
                                          tab.tab_text,
                                          result)
        if !result.nil? and not string.strip.empty? and @tab_book.tabText(tab_index) != string
          tab.tab_text = string
          @tab_book.setTabText(tab_index, string)
          edited = true
          @config_modified_callback.call() if @config_modified_callback
        end
      end

      return edited
    end # def edit_tab

    # Export all data objects on a tab - defaults to current tab
    def export_tab(filename, progress, tab_index = nil)
      # Select the current tab by default
      tab_index = current_tab_index() unless tab_index

      if tab_index
        # Export the tab's data objects
        export_data_objects(filename, progress, tab_index) if @tabbed_plots_config.tabs[tab_index]
      end
    end # def export_tab

    # Reset all data objects on a tab - defaults to current tab
    def reset_tab(tab_index = nil)
      # Select the current tab by default
      tab_index = current_tab_index() unless tab_index

      # Reset the data objects
      reset_data_objects(tab_index) if tab_index
    end

    # Take screenshot of current tab and write to filename
    def screenshot_tab(filename)
      # Select the current tab
      tab_index = current_tab_index()

      if tab_index
        # Take screenshot
        Screenshot.screenshot_window(@tab_book.currentWidget(), filename)
      end
    end # def screenshot_tab

    # Returns the index of the current tab or nil if no tabs exist
    def current_tab_index
      unless @tabbed_plots_config.tabs.empty?
        tab_index = @tab_book.currentIndex
        return tab_index if tab_index >= 0
      end
      nil
    end # def current_tab_index

    # Indicates if the tab has any data objects
    def tab_has_data_objects?(tab_index = nil)
      # Select the current tab by default
      tab_index = current_tab_index() unless tab_index

      return_value = false
      if tab_index
        @tabbed_plots_config.mu_synchronize do
          @tabbed_plots_config.tabs[tab_index].plots.each do |plot|
            if not plot.data_objects.empty?
              return_value = true
              break
            end
          end
        end
      end

      return_value
    end

    ###############################################################################
    # Plot Related Methods
    ###############################################################################

    # Add a new plot to a tab - defaults to the current tab
    def add_plot(tab_index = nil, dialog = true)
      # Select the current tab by default
      tab_index = current_tab_index() unless tab_index

      if tab_index
        # Get Tab
        tab = @tabbed_plots_config.tabs[tab_index]

        # Add to config
        if dialog
          plot_editor = TabbedPlotsPlotEditor.new(self,
                                                  'Add Plot',
                                                  @tabbed_plots_config.plot_types)
          plot = plot_editor.execute
          plot_editor.dispose
        else
          plot = @tabbed_plots_config.create_plot(@tabbed_plots_config.plot_types[0])
        end
        if plot
          @tabbed_plots_config.add_plot(tab_index, plot)
          @status_bar.showMessage(tr("Add Plot Succeeded"))
        else
          @status_bar.showMessage(tr("Add Plot Canceled"))
          return false
        end

        # Create new plot gui object
        filename = plot.plot_type.downcase + '_plot_gui_object.rb'
        gui_object = Cosmos.require_class(filename).new(tab.gui_item, tab, plot, self)
        tab.gui_layout.addWidget(gui_object)
        plot.gui_object = gui_object
        #~ plot.gui_object.connect(SEL_RIGHTBUTTONRELEASE, method(:handle_plot_right_button_release))
        if plot.gui_object.respond_to? :mouse_left_button_press_callback
          current_tab = tab
          plot.gui_object.mouse_left_button_press_callback = lambda do |calling_gui_object|
            current_tab.plots.each_with_index do |current_plot, index|
              if current_plot.gui_object == calling_gui_object
                select_plot(current_plot)
              else
                unselect_plot(current_plot)
              end
            end
            @overview_graphs[@tab_book.currentIndex].setFocus
          end
        end

        # Auto-select plot
        unselect_all_plots(tab_index)
        select_plot(plot)
      end
      @config_modified_callback.call() if @config_modified_callback
      return true
    end # def add_plot

    # Delete a plot - defaults to the selected plot on the current tab
    def delete_plot(tab_index = nil, plot_index = nil)
      # Select the current tab by default
      tab_index = current_tab_index() unless tab_index

      # Select selected plot by default
      plot_index = selected_plot_index(tab_index) if tab_index and not plot_index

      # Make sure the plot exists
      if plot_index
        # Get Tab
        tab = @tabbed_plots_config.tabs[tab_index]

        # Remove from config
        plot = @tabbed_plots_config.remove_plot(tab_index, plot_index)

        # Potentially clear data object list
        clear_data_object_list() if plot.gui_object.selected?

        # Remove the widget
        tab.gui_layout.removeWidget(plot.gui_object)
        plot.gui_object.dispose

        # Create new layout
        layout = Qt::AdaptiveGridLayout.new

        # Add existing gui objects into new layout
        (0...tab.gui_layout.count).each do |index|
          layout.addWidget(tab.gui_layout.takeAt(0).widget)
        end

        # Select the first plot just to be nice
        select_plot(tab.plots[0]) if tab.plots[0]

        # Remove existing layout from frame
        tab.gui_frame.removeItem(tab.gui_layout)
        # Assign new layout to tab
        tab.gui_frame.insertLayout(0, layout, 1)
        tab.gui_layout = layout
        #~ tab.gui_layout.connect(SEL_RIGHTBUTTONRELEASE, method(:handle_plot_right_button_release))

        @status_bar.showMessage(tr("Plot Deleted"))
        @config_modified_callback.call() if @config_modified_callback
      else
        Qt::MessageBox.information(self, 'Information', 'Please select a plot')
      end
    end # def delete_plot

    # Edit a plot - defaults to the selected plot on the current tab
    def edit_plot(tab_index = nil, plot_index = nil)
      edited = false

      # Select the current tab by default
      tab_index = current_tab_index() unless tab_index

      if tab_index
        # Get tab
        tab = @tabbed_plots_config.tabs[tab_index]

        # Select selected plot by default
        plot_index = selected_plot_index(tab_index) unless plot_index
        unless plot_index
          Qt::MessageBox.information(self, 'Information', 'Please select a plot')
          return
        end
        plot = tab.plots[plot_index]

        # Edit Plot
        plot_editor = TabbedPlotsPlotEditor.new(self,
                                                'Edit Plot',
                                                @tabbed_plots_config.plot_types,
                                                plot)
        plot = plot_editor.execute
        plot_editor.dispose
        if plot
          plot.gui_object.update(true)
          @status_bar.showMessage(tr("Plot Edited"))
          edited = true
          @config_modified_callback.call() if @config_modified_callback
        else
          @status_bar.showMessage(tr("Plot Edit Canceled"))
        end
      end

      return edited
    end # def edit_plot

    # Exports data objects on a plot - defaults to selected plot on the current tab
    def export_plot(filename, progress, tab_index = nil, plot_index = nil)
      Qt.execute_in_main_thread(true) do
        # Select the current tab by default
        tab_index = current_tab_index() unless tab_index

        # Select selected plot by default
        plot_index = selected_plot_index(tab_index) if tab_index and not plot_index
        unless plot_index
          Qt::MessageBox.information(self, 'Information', 'Please select a plot')
          return
        end
      end

      export_data_objects(filename, progress, tab_index, plot_index)
    end # def export_plot

    # Take screenshot of a plot on the current tab and write to filename - defaults to selected plot
    def screenshot_plot(filename, plot_index = nil)
      # Select the current tab by default
      tab_index = current_tab_index() unless tab_index

      # Select selected plot by default
      plot_index = selected_plot_index(tab_index) if tab_index and not plot_index

      # Take screenshot
      Screenshot.screenshot_window(@tabbed_plots_config.tabs[tab_index].plots[plot_index].gui_object, filename) if plot_index
    end # def screenshot_plot

    # Reset all data objects on a plot - defaults to the selected plot on the current tab
    def reset_plot(tab_index = nil, plot_index = nil)
      # Select the current tab by default
      tab_index = current_tab_index() unless tab_index

      # Select selected plot by default
      plot_index = selected_plot_index(tab_index) if tab_index and not plot_index

      # Reset the data objects
      reset_data_objects(tab_index, plot_index) if plot_index
    end

    # Returns the index of the selected plot or nil - looks at current tab by default
    def selected_plot_index(tab_index = nil)
      # Select the current tab by default
      tab_index = current_tab_index() unless tab_index

      if tab_index
        @tabbed_plots_config.tabs[tab_index].plots.each_with_index do |plot, index|
          return index if plot.gui_object.selected?
        end
      end
      nil
    end # def selected_plot_index

    # Indicates if the plot has any data objects
    def plot_has_data_objects?(tab_index = nil, plot_index = nil)
      # Select the current tab by default
      tab_index = current_tab_index() unless tab_index

      # Select selected plot by default
      plot_index = selected_plot_index(tab_index) if tab_index and not plot_index

      return_value = false
      if plot_index
        @tabbed_plots_config.mu_synchronize do
          return_value = true unless @tabbed_plots_config.tabs[tab_index].plots[plot_index].data_objects.empty?
        end
      end

      return_value
    end

    ###############################################################################
    # Data Object Related Methods
    ###############################################################################

    # Adds a data object to a plot - defaults to selected plot on the current tab
    def add_data_object(tab_index = nil, plot_index = nil, data_object = nil)
      # Select the current tab by default
      tab_index = current_tab_index() unless tab_index

      # Select selected plot by default
      plot_index = selected_plot_index(tab_index) if tab_index and not plot_index
      unless plot_index
        Qt::MessageBox.information(self, 'Information', 'Please select a plot')
        return false
      end

      # Get plot
      plot = @tabbed_plots_config.tabs[tab_index].plots[plot_index]

      # Start data object editor to create new data object
      unless data_object
        data_object_editor = TabbedPlotsDataObjectEditor.new(self,'Add Data Object', @tabbed_plots_config.plot_type_to_data_object_type_mapping[plot.plot_type])
        data_object = data_object_editor.execute
        data_object_editor.dispose
        unless data_object
          @status_bar.showMessage(tr("Add Data Object Canceled"))
          return false
        end
      end

      # Assign color to data object
      data_object.color = get_free_color(@tabbed_plots_config.tabs[tab_index]) unless data_object.assigned_color

      # Add to config
      @tabbed_plots_config.add_data_object(tab_index, plot_index, data_object)
      @tabbed_plots_config.update_max_points_saved(@points_saved.value)

      # Update Plot
      @tabbed_plots_config.tabs[tab_index].plots[plot_index].gui_object.update(true)

      # Update data object list
      fill_data_object_list_for_plot(@tabbed_plots_config.tabs[tab_index].plots[plot_index])

      @status_bar.showMessage(tr("Add Data Object Succeeded"))
      @config_modified_callback.call() if @config_modified_callback
      return true
    end # def add_data_object

    # Deletes a data object from a plot - defaults to the selected data objects on the selected plot on the current tab
    def delete_data_object(tab_index = nil, plot_index = nil, data_object_index = nil)
      # Select the current tab by default
      tab_index = current_tab_index() unless tab_index

      # Select selected plot by default
      plot_index = selected_plot_index(tab_index) if tab_index and not plot_index
      plot = @tabbed_plots_config.tabs[tab_index].plots[plot_index]

      data_object_indexes = get_data_object_indexes(plot,
                                                    tab_index,
                                                    plot_index,
                                                    data_object_index)
      data_object_indexes.reverse_each do |data_object_idx|
        @tabbed_plots_config.remove_data_object(tab_index, plot_index, data_object_idx)
      end

      if plot
        plot.gui_object.update(true)
        fill_data_object_list_for_plot(plot)
      end
      @config_modified_callback.call() if @config_modified_callback
    end # def delete_data_object

    # Edits a data object on a plot - defaults to the selected data objects on the selected plot on the current tab
    def edit_data_object(tab_index = nil, plot_index = nil, data_object_index = nil)
      edited = false

      # Select the current tab by default
      tab_index = current_tab_index() unless tab_index

      # Select selected plot by default
      plot_index = selected_plot_index(tab_index) if tab_index and not plot_index
      if plot_index
        plot = @tabbed_plots_config.tabs[tab_index].plots[plot_index]

        data_object_indexes = get_data_object_indexes(plot,
                                                      tab_index,
                                                      plot_index,
                                                      data_object_index)
        data_object_indexes.each do |data_object_idx|
          data_object = @tabbed_plots_config.tabs[tab_index].plots[plot_index].data_objects[data_object_idx]
          data_object_editor = TabbedPlotsDataObjectEditor.new(self, 'Edit Data Object', @tabbed_plots_config.plot_type_to_data_object_type_mapping[plot.plot_type], data_object)
          data_object = data_object_editor.execute
          data_object_editor.dispose
          if data_object
            @tabbed_plots_config.edit_data_object(tab_index, plot_index, data_object_idx, data_object)
            @status_bar.showMessage(tr("Data Object(s) Edited"))
            edited = true
            @config_modified_callback.call() if @config_modified_callback
          else
            @status_bar.showMessage(tr("Edit Data Object Canceled"))
          end
        end

        plot.gui_object.update(true)
        fill_data_object_list_for_plot(plot)
      end

      return edited
    end # def edit_data_object

    # Duplicates a data object on a plot - defaults to the selected data objects on the selected plot on the current tab
    def duplicate_data_object(tab_index = nil, plot_index = nil, data_object_index = nil)
      # Select the current tab by default
      tab_index = current_tab_index() unless tab_index

      # Select selected plot by default
      plot_index = selected_plot_index(tab_index) if tab_index and not plot_index
      if plot_index
        plot = @tabbed_plots_config.tabs[tab_index].plots[plot_index]

        data_object_indexes = get_data_object_indexes(plot,
                                                      tab_index,
                                                      plot_index,
                                                      data_object_index)
        data_object_indexes.each do |data_object_idx|
          data_object = @tabbed_plots_config.duplicate_data_object(tab_index, plot_index, data_object_idx)
          data_object.color = get_free_color(@tabbed_plots_config.tabs[tab_index]) unless data_object.assigned_color
        end
        @status_bar.showMessage(tr("Data Object(s) Duplicated"))

        plot.gui_object.update(true)
        fill_data_object_list_for_plot(@tabbed_plots_config.tabs[tab_index].plots[plot_index])
        @config_modified_callback.call() if @config_modified_callback
      end
    end # def duplicate_data_object

    # Exports a data object on a plot - defaults to the selected data objects on the selected plot on the current tab
    def export_data_object(filename, progress, tab_index = nil, plot_index = nil, data_object_index = nil)
      # Select the current tab by default
      tab_index = current_tab_index() unless tab_index

      # Select selected plot by default
      plot_index = selected_plot_index(tab_index) if tab_index and not plot_index
      if plot_index
        plot = @tabbed_plots_config.tabs[tab_index].plots[plot_index]

        data_object_indexes = get_data_object_indexes(plot,
                                                      tab_index,
                                                      plot_index,
                                                      data_object_index)

        columns = []
        data_object_indexes.each do |data_object_idx|
          columns.concat(@tabbed_plots_config.export_data_objects(progress, tab_index, plot_index, data_object_idx))
        end
        write_export_file(filename, columns, progress)
      end
    end # def export_data_object

    # Exports all data objects
    def export_all_data_objects(filename, progress)
      export_data_objects(filename, progress)
    end # def export_all_data_objects

    # Resets a data object on a plot - defaults to the selected data objects on the selected plot on the current tab
    def reset_data_object(tab_index = nil, plot_index = nil, data_object_index = nil)
      # Select the current tab by default
      tab_index = current_tab_index() unless tab_index

      # Select selected plot by default
      plot_index = selected_plot_index(tab_index) if tab_index and not plot_index

      if plot_index
        data_object_indexes = selected_data_object_indexes()
        data_object_indexes.reverse_each do |data_object_idx|
          @tabbed_plots_config.reset_data_objects(tab_index, plot_index, data_object_idx)
        end
        redraw_plots(true, true)
        @status_bar.showMessage(tr("Data Object(s) Reset"))
      end
    end

    # Resets all data objects
    def reset_all_data_objects
      reset_data_objects()
    end # def reset_all_data_objects

    # Returns an array with the indexes of the selected data objects
    def selected_data_object_indexes
      selected = []
      index = 0
      @data_object_list.each do |list_item|
        selected << index if list_item.selected? and @data_object_list.item(index).text != 'No Plot Selected'
        index += 1
      end
      selected
    end # def selected_data_object_indexes

    # Redraws all plots that need to be redrawn
    def redraw_plots(force_redraw = false, force_move_window = false)
      if not @paused or force_redraw
        overview_redraw_needed = force_redraw
        move_window = force_move_window
        points_plotted = @points_plotted.value

        # Determine if overview redraws are needed
        @tabbed_plots_config.mu_synchronize do
          tab_index = @tab_book.currentIndex
          return if tab_index < 0 or tab_index > (@tabbed_plots_config.tabs.length - 1)
          @tabbed_plots_config.tabs[tab_index].plots.each do |plot|
            if plot.redraw_needed
              overview_redraw_needed = true
              move_window = true unless @paused
              break
            end
          end
        end

        # Redraw overview
        overview_graph = @overview_graphs[@tab_book.currentIndex]
        if overview_redraw_needed
          num_lines = 0
          @tabbed_plots_config.tabs[@tab_book.currentIndex].plots.each {|plot| num_lines += plot.data_objects.length}
          if num_lines > 0
            overview_points_plotted = points_plotted / num_lines
            overview_points_plotted = MINIMUM_OVERVIEW_POINTS_PLOTTED if overview_points_plotted < MINIMUM_OVERVIEW_POINTS_PLOTTED
          else
            overview_points_plotted = points_plotted
          end

          overview_graph.clear_lines
          @tabbed_plots_config.mu_synchronize do
            @tabbed_plots_config.tabs[@tab_book.currentIndex].plots.each {|plot| plot.gui_object.update_overview(overview_points_plotted, overview_graph)}
          end

          overview_graph.graph(move_window)
        end

        # Sync other overview graph positions
        @overview_graphs.each do |other_overview_graph|
          if overview_graph != other_overview_graph
            other_overview_graph.set_window_pos(overview_graph.window_min_x, overview_graph.window_max_x, false)
          end
        end

        # Determine if plot redraws needed
        gui_objects = []
        redraw_needed = []
        @tabbed_plots_config.mu_synchronize do
          @tabbed_plots_config.tabs[@tab_book.currentIndex].plots.each do |plot|
            gui_objects << plot.gui_object
            if force_redraw or overview_redraw_needed
              redraw_needed << true
            else
              redraw_needed << plot.redraw_needed
            end
            if redraw_needed[-1]
              plot.gui_object.update_plot(points_plotted, overview_graph.window_min_x, overview_graph.window_max_x)
            end
          end
        end

        # Redraw plots
        gui_objects.length.times do |index|
          if redraw_needed[index]
            gui_objects[index].redraw
          end
        end

      end
    end # def redraw_plots

    protected

    def get_data_object_indexes(plot, tab_index, plot_index, data_object_index)
      if data_object_index
        return unless (plot and @tabbed_plots_config.tabs[tab_index].plots[plot_index].data_objects[data_object_index])
        data_object_indexes = [data_object_index]
      else
        data_object_indexes = selected_data_object_indexes()
      end
    end

    # Resets data objects and redraws the plots
    def reset_data_objects(tab_index = nil, plot_index = nil, data_object_index = nil)
      @tabbed_plots_config.reset_data_objects(tab_index, plot_index, data_object_index)
      redraw_plots(true, true)
    end # def reset_data_objects

    def write_export_file(filename, columns, progress)
      max_column_size = 0
      columns.each {|column| max_column_size = column.length if column.length > max_column_size}
      File.open(filename, 'w') do |file|
        max_column_size.times do |index|
          string = ''
          columns.each {|column| string << column[index].to_s << "\t"}
          file.puts(string)
          progress.set_overall_progress(index.to_f / max_column_size)
        end
      end
    end

    # Exports data objects to a file
    def export_data_objects(filename, progress, tab_index = nil, plot_index = nil, data_object_index = nil)
      columns = @tabbed_plots_config.export_data_objects(progress, tab_index, plot_index, data_object_index)
      write_export_file(filename, columns, progress)
    end # def export_data_objects

    # Create GUI objects
    def create
      # Select first plot on each tab in reverse order
      @tabbed_plots_config.tabs.reverse_each {|tab| select_plot(tab.plots[0]) if tab.plots[0]}

      # Setup timeout to redraw graphs
      @timeout = Qt::Timer.new(self)
      @timeout.connect(SIGNAL('timeout()')) { redraw_plots() }
      @timeout.method_missing(:start, @refresh_rate_ms)
    end # def create

    # Clears the data object list
    def clear_data_object_list
      # Clear data object list
      @data_object_list.clearItems
      @data_object_list.addItemColor('No Plot Selected')
    end # def clear_data_object_list

    # Fills the data object list for the specified plot
    def fill_data_object_list_for_plot(plot)
      # List Data Objects for this plot
      @data_object_list.clearItems
      plot.data_objects.each do |data_object|
        @data_object_list.addItemColor(data_object.name, data_object.color)
      end
    end # def fill_data_object_list_for_plot

    # Gets an available color on a tab - if no colors are available a random color
    # is returned
    def get_free_color(tab)
      color = nil
      colors = []
      default_colors = DataObject::COLOR_LIST.clone
      tab.plots.each do |plot|
        plot.data_objects.each {|data_object| colors << data_object.color}
      end
      color = default_colors.shift
      while (color and colors.include?(color))
        color = default_colors.shift
      end
      color = get_random_color() unless color
      color
    end # def get_free_color

    # Gets a random color
    def get_random_color
      random_index = (rand() * DataObject::COLOR_LIST.length).floor
      random_index = (DataObject::COLOR_LIST.length  - 1) if random_index >= DataObject::COLOR_LIST.length
      DataObject::COLOR_LIST[random_index].clone
    end # def get_random_color

    # Builds the left frame of the tool
    def build_left_frame
      # Frame around everything
      @tabbed_plots_left_frame = Qt::VBoxLayout.new
      @left_frame.addLayout(@tabbed_plots_left_frame)

      # Seconds Plotted
      @seconds_plotted = FloatChooser.new(self,
                                          'Seconds Plotted:',
                                          @tabbed_plots_config.seconds_plotted,
                                          0.0,
                                          nil,
                                          15)
      @seconds_plotted.sel_command_callback = method(:handle_seconds_plotted_change)
      @tabbed_plots_left_frame.addWidget(@seconds_plotted)

      # Points Saved
      @points_saved = IntegerChooser.new(self, 'Points Saved:', @tabbed_plots_config.points_saved, 1, nil, 15)
      @points_saved.sel_command_callback = method(:handle_points_saved_change)
      @tabbed_plots_left_frame.addWidget(@points_saved)

      # Points Plotted
      @points_plotted = IntegerChooser.new(self,
                                           'Points Plotted:',
                                           @tabbed_plots_config.points_plotted,
                                           2,
                                           nil,
                                           15)
      @points_plotted.sel_command_callback = method(:handle_points_plotted_change)
      @tabbed_plots_left_frame.addWidget(@points_plotted)

      # Refresh Rate Hz
      @refresh_rate_hz = FloatChooser.new(self,
                                          'Refresh Rate Hz:',
                                          @tabbed_plots_config.refresh_rate_hz,
                                          0.000001,
                                          1000.0,
                                          15)
      @refresh_rate_hz.sel_command_callback = method(:handle_refresh_rate_hz_change)
      @tabbed_plots_left_frame.addWidget(@refresh_rate_hz)

      # Update overview graphs
      @overview_graphs.each {|overview_graph| overview_graph.window_size = @tabbed_plots_config.seconds_plotted}

      # Adders
      add_adders(@tabbed_plots_left_frame) if @adder_orientation == Qt::Vertical

      # Separator before list
      sep = Qt::Frame.new
      sep.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
      @tabbed_plots_left_frame.addWidget(sep)

      # Data Object List
      @tabbed_plots_left_frame.addWidget(Qt::Label.new('Data Objects:'))
      @data_object_list = Qt::ColorListWidget.new(self, false)
      @data_object_list.setSelectionMode(Qt::AbstractItemView::ExtendedSelection)
      @data_object_list.setContextMenuPolicy(Qt::CustomContextMenu)
      @data_object_list.setDragDropMode(Qt::AbstractItemView::InternalMove)
      @data_object_list.define_singleton_method(:keyPressEvent) do |event|
        case event.key
        when Qt::Key_Delete, Qt::Key_Backspace
          otp = self.original_parent
          unless otp.selected_data_object_indexes.empty?
            paused = otp.paused?()
            otp.pause()
            result = Qt::MessageBox.warning(self,
                                            'Warning!',
                                            "Are you sure you want to delete the selected data objects?",
                                            Qt::MessageBox::Yes | Qt::MessageBox::No, Qt::MessageBox::No)
            if result == Qt::MessageBox::No
              otp.status_bar.showMessage(tr("Data Object Deletion Canceled"))
            else
              otp.status_bar.showMessage(tr("Data Object Deleted"))
              otp.delete_data_object()
            end
            otp.resume() unless paused
          end
        end
        super(event)
      end
      connect(@data_object_list.model,
              SIGNAL('rowsMoved(const QModelIndex&, int, int, const QModelIndex&, int)'),
              self,
              SLOT('data_object_moved(const QModelIndex&, int, int, const QModelIndex&, int)'))
      connect(@data_object_list,
              SIGNAL('customContextMenuRequested(const QPoint&)'),
              self,
              SLOT('data_object_context_menu(const QPoint&)'))
      @data_object_list.connect(SIGNAL('itemClicked(QListWidgetItem*)')) do
        @status_bar.showMessage(tr("Drag and drop to reorder. Items are drawn in order from top to bottom."))
      end
      @data_object_list.addItemColor('No Plot Selected')
      @tabbed_plots_left_frame.addWidget(@data_object_list)
      @tabbed_plots_config.update_max_points_saved(@points_saved.value)
    end # def build_left_frame

    # Handler for points saved changing
    def handle_points_saved_change(value_string, value_integer)
      if value_integer < @tabbed_plots_config.points_saved
        paused = paused?()
        pause()
        result = Qt::MessageBox.warning(self,
                                        'Warning!',
                                        "Reducing Points Saved May Discard Data! Discard?",
                                        Qt::MessageBox::Yes | Qt::MessageBox::No, Qt::MessageBox::No)
        resume() unless paused
        if result == Qt::MessageBox::No
          @points_saved.value = @tabbed_plots_config.points_saved
          return
        end
      end

      @tabbed_plots_config.points_saved = value_integer
      @tabbed_plots_config.update_max_points_saved(value_integer)

      redraw_plots(true)
      @config_modified_callback.call() if @config_modified_callback
    end # def handle_points_saved_change

    # Handler for seconds plotted changing
    def handle_seconds_plotted_change(value_string, value_float)
      @overview_graphs.each {|overview_graph| overview_graph.window_size = value_float}
      @tabbed_plots_config.seconds_plotted = value_float
      @config_modified_callback.call() if @config_modified_callback
    end # def handle_seconds_plotted_change

    # Handler for points plotted changing
    def handle_points_plotted_change(value_string, value_integer)
      redraw_plots(true)
      @tabbed_plots_config.points_plotted = value_integer
      @config_modified_callback.call() if @config_modified_callback
    end # def handle_points_plotted_change

    # Handler for refresh rate hz changing
    def handle_refresh_rate_hz_change(value_string, value_float)
      redraw_plots(true)
      @tabbed_plots_config.refresh_rate_hz = value_float
      @refresh_rate_ms = (1000.0 / value_float).round

      @timeout.method_missing(:stop)
      @timeout.method_missing(:start, @refresh_rate_ms)
      @config_modified_callback.call() if @config_modified_callback
    end # def handle_points_plotted_change

    # Adds the adders
    def add_adders(layout)
      # Data Object Adders
      @data_object_adders = []

      if @adder_types
        type_list = @adder_types
      else
        type_list = @tabbed_plots_config.data_object_types
      end

      type_list.each do |data_object_type|
        begin
          filename = data_object_type.to_s.downcase + '_data_object_adder'
          @data_object_adders << Cosmos.require_class(filename).new(self, @adder_orientation)
          layout.addWidget(@data_object_adders[-1])
          @data_object_adders[-1].add_data_object_callback = method(:adder_add_data_object)
          @data_object_adders[-1].update
        rescue Exception
          # No adder for this type
        end
      end
    end # def add_adders

    # Method called by adders to add a data object
    def adder_add_data_object(data_object)
      tab_index = current_tab_index()
      plot_index = selected_plot_index(tab_index)
      if plot_index
        plot = @tabbed_plots_config.tabs[tab_index].plots[plot_index]
        mapping = @tabbed_plots_config.plot_type_to_data_object_type_mapping[plot.plot_type]
        if mapping.include?(data_object.data_object_type)
          add_data_object(tab_index, plot_index, data_object)
        else
          paused = paused?()
          pause()
          Qt::MessageBox.critical(self, 'Error', "A #{data_object.data_object_type} data object cannot be added to a #{plot.plot_type} plot")
          resume() unless paused
        end
      else
        paused = paused?()
        pause()
        Qt::MessageBox.information(self, 'Information', 'Please select a plot')
        resume() unless paused
      end
    end # def adder_add_data_object

    # Builds the GUI holding tabs and plots
    def build_right_frame
      # Frame around everything
      @tabbed_plots_right_frame = Qt::VBoxLayout.new
      @right_frame.addLayout(@tabbed_plots_right_frame)

      # Adders
      add_adders(@tabbed_plots_right_frame) if @adder_orientation == Qt::Horizontal

      # Tabbook to hold tabs
      @tab_book = Qt::TabWidget.new
      @tab_book.setContextMenuPolicy(Qt::CustomContextMenu)
      connect(@tab_book,
              SIGNAL('customContextMenuRequested(const QPoint&)'),
              self,
              SLOT('tab_context_menu(const QPoint&)'))
      @tabbed_plots_right_frame.addWidget(@tab_book)

      # Array of overview graphs and graph times
      @overview_graphs  = []
      @graph_time_start = []
      @graph_time_end   = []

      # Create each tab
      @tabbed_plots_config.mu_synchronize do
        @tabbed_plots_config.tabs.each_with_index do |tab, tab_index|
          # Maximize graph start and end times
          @graph_time_start << -1.0e300
          @graph_time_end   << 1.0e300

          # Create tab item for the tab
          tab_text = tab.tab_text
          tab_text = "Tab #{tab_index + 1}" unless tab_text
          tab_item = Qt::Widget.new
          tab_item.setContextMenuPolicy(Qt::CustomContextMenu)
          connect(tab_item, SIGNAL('customContextMenuRequested(const QPoint&)'), self, SLOT('plot_context_menu(const QPoint&)'))

          # Create overall vertical layout manager for tab.
          tab_layout = Qt::VBoxLayout.new()
          tab_item.setLayout(tab_layout)
          tab.gui_item = tab_item
          tab.gui_frame = tab_layout
          tab.tab_text = tab_text

          # Create layout manager to hold plots based on number of plots
          layout = Qt::AdaptiveGridLayout.new
          tab.gui_layout = layout

          # Add with stretch factor 1 to give it priority over everything else
          tab_layout.addLayout(layout, 1)
          # Add stretch in case they delete the last plot.
          # This will force the overview graph (which doesn't get deleted)
          # to stay at the bottom of the layout instead of moving
          tab_layout.addStretch()

          @tab_book.addTab(tab_item, tab_text)

          # Create gui object for each plot
          default_colors = DataObject::COLOR_LIST.clone
          tab.plots.each_with_index do |plot, index|
            filename = plot.plot_type.downcase + '_plot_gui_object.rb'
            gui_object = Cosmos.require_class(filename).new(tab_item, tab, plot, self)
            tab.gui_layout.addWidget(gui_object)
            plot.gui_object = gui_object
            if plot.gui_object.respond_to? :mouse_left_button_press_callback
              current_tab = tab
              plot.gui_object.mouse_left_button_press_callback = lambda do |calling_gui_object|
                current_tab.plots.each do |current_plot|
                  if current_plot.gui_object == calling_gui_object
                    select_plot(current_plot)
                  else
                    unselect_plot(current_plot)
                  end
                end
                @overview_graphs[@tab_book.currentIndex].setFocus
              end
            end

            # Configure colors
            colors = []
            plot.data_objects.each do |data_object|
              if data_object.assigned_color
                colors << data_object.assigned_color
              else
                color = default_colors.shift
                while (color and colors.include?(color))
                  color = default_colors.shift
                end
                color = get_random_color() unless color
                colors << color
                data_object.color = color
              end
            end
          end # tab.plots.each

          # Add an overview graph to the tab
          @overview_graphs << OverviewGraph.new(tab_item)
          @overview_graphs[-1].window_size = @tabbed_plots_config.seconds_plotted
          @overview_graphs[-1].callback = method(:overview_graph_callback)
          tab_layout.addWidget(@overview_graphs[-1])
        end # tabs.each
      end
      # Attach this handler last so it doesn't fire when we create our first tab
      connect(@tab_book,
              SIGNAL('currentChanged(int)'),
              self,
              SLOT('handle_tab_change(int)'))
    end # def build_right_frame

    # Function called by the overview graph on changes
    def overview_graph_callback(modified_overview_graph)
      if modified_overview_graph.window_size > 0.01
        @seconds_plotted.value = sprintf("%0.2f", modified_overview_graph.window_size)
      else
        @seconds_plotted.value = modified_overview_graph.window_size
      end
      @overview_graphs.each do |overview_graph|
        if overview_graph != modified_overview_graph
          overview_graph.set_window_size(modified_overview_graph.window_size, false)
          overview_graph.set_window_pos(modified_overview_graph.window_min_x, modified_overview_graph.window_max_x, false)
        end
      end
      redraw_plots(true)
      # Intentially not have adjusting the view window in the overview graph
      # be considered a configuration change
    end # def overview_graph_callback

    # Selects the specified plot
    def select_plot(plot)
      unless plot.gui_object.selected?
        plot.gui_object.select
        fill_data_object_list_for_plot(plot)
      end
    end # def select_plot

    # Unselects the specified plot
    def unselect_plot(plot)
      plot.gui_object.unselect if plot.gui_object.selected?
    end # def unselect_plot

    # Unselects all plots on a tab
    def unselect_all_plots(tab_index = nil)
      tab_index = @tab_book.current unless tab_index
      return if tab_index < 0 or @tabbed_plots_config.tabs[tab_index].nil?
      @tabbed_plots_config.tabs[tab_index].plots.each do |plot|
        unselect_plot(plot)
      end
    end # def unselect_all_plots

    ############################################################################
    # Slot implementation
    ############################################################################

    # Handles right clicks on a tab
    def tab_context_menu(point)
      index = 0
      (0..@tab_book.tabBar.count).each do |bar|
        index = bar
        break if @tab_book.tabBar.tabRect(bar).contains(point)
      end
      return if (index == @tab_book.tabBar.count)
      @tab_book.setCurrentIndex(index)

      @tab_item_right_button_release_callback.call(@tab_book.mapToGlobal(point)) if @tab_item_right_button_release_callback
    end

    # Handles right clicks on a plot
    def plot_context_menu(point)
      tab_index = @tab_book.currentIndex
      return if tab_index < 0 or @tabbed_plots_config.tabs[tab_index].nil?
      plot_point = nil
      @tabbed_plots_config.tabs[tab_index].plots.each do |plot|
        plot_point = @tab_book.widget(tab_index).mapToGlobal(point) if plot.gui_object.selected?
      end

      @plot_right_button_release_callback.call(plot_point) if @plot_right_button_release_callback and plot_point
    end

    # Handles a right click on a data object
    def data_object_context_menu(point)
      @data_object_right_button_release_callback.call(@data_object_list.mapToGlobal(point)) if @data_object_right_button_release_callback
    end

    # Handles data objects being moved
    def data_object_moved(sourceParent, sourceStart, sourceEnd, destinationParent, destinationRow)
      start_index = sourceStart
      if sourceStart < destinationRow
        end_index = destinationRow - 1
      else
        end_index = destinationRow
      end
      tab_index = current_tab_index()
      plot_index = selected_plot_index(tab_index)
      @tabbed_plots_config.move_data_object(tab_index, plot_index, start_index, end_index)
      @config_modified_callback.call() if @config_modified_callback
    end

    # Handles tab change events
    def handle_tab_change(tab_index)
      if @tab_book.count > 0
        plot_index = selected_plot_index(tab_index)
        if plot_index
          plot = @tabbed_plots_config.tabs[tab_index].plots[plot_index]
          fill_data_object_list_for_plot(plot)
        else
          clear_data_object_list()
        end
        redraw_plots(true)
      end
    end # def handle_tab_change

  end # class OverviewTabbedPlots

end # module Cosmos
