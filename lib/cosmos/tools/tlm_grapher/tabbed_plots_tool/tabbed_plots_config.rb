# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/ext/tabbed_plots_config' if RUBY_ENGINE == 'ruby' and !ENV['COSMOS_NO_EXT']
require 'cosmos/tools/tlm_grapher/tabbed_plots_tool/tabbed_plots_tab'
require 'cosmos/tools/tlm_grapher/plots/plot'
require 'cosmos/tools/tlm_grapher/plots/linegraph_plot'
require 'cosmos/tools/tlm_grapher/plots/xy_plot'
require 'cosmos/tools/tlm_grapher/plots/singlexy_plot'
require 'cosmos/tools/tlm_grapher/data_objects/data_object'
require 'cosmos/tools/tlm_grapher/data_objects/linegraph_data_object'
require 'cosmos/tools/tlm_grapher/data_objects/housekeeping_data_object'
require 'cosmos/tools/tlm_grapher/data_objects/xy_data_object'
require 'cosmos/tools/tlm_grapher/data_objects/singlexy_data_object'

module Cosmos
  # Provides capabilities to read an ascii file that lists
  # the details for a set of plots drawn in tabs.
  class TabbedPlotsConfig
    # Default Values
    DEFAULT_SECONDS_PLOTTED = 100.0
    DEFAULT_POINTS_SAVED = 1000000
    DEFAULT_POINTS_PLOTTED = 1000
    DEFAULT_REFRESH_RATE_HZ = 10.0
    DEFAULT_CTS_TIMEOUT = 60.0

    # Gives access to the array of tabs defined by the configuration file
    attr_accessor :tabs

    # Global Seconds Plotted Setting
    attr_accessor :seconds_plotted

    # Global Points Saved Setting
    attr_accessor :points_saved

    # Global Points Plotted Setting
    attr_accessor :points_plotted

    # Global Refresh Rate Hz Setting
    attr_accessor :refresh_rate_hz

    # Global CTS Timeout Setting
    attr_accessor :cts_timeout

    # Plot types known by this tabbed plots definition
    attr_accessor :plot_types

    # Data object types known by this tabbed plots definition
    attr_accessor :data_object_types

    # Mapping of what data object types a plot can handle
    attr_accessor :plot_type_to_data_object_type_mapping

    # Gives access to array of errors that occurred while processing configuration file
    attr_accessor :configuration_errors

    # Processes a file and adds in the configuration defined in the file
    def initialize(filename,
                   plot_types,
                   data_object_types,
                   plot_type_to_data_object_type_mapping)
      @plot_types = plot_types
      @data_object_types = data_object_types
      @plot_type_to_data_object_type_mapping = plot_type_to_data_object_type_mapping

      @mutex = Mutex.new
      @tabs = []
      @points_saved = DEFAULT_POINTS_SAVED
      @seconds_plotted = DEFAULT_SECONDS_PLOTTED
      @points_plotted = DEFAULT_POINTS_PLOTTED
      @refresh_rate_hz = DEFAULT_REFRESH_RATE_HZ
      @cts_timeout = DEFAULT_CTS_TIMEOUT
      @packet_count = 0
      @configuration_errors = []

      if File.exist?(filename.to_s)
        # Loop over each line of the configuration file
        parser = ConfigParser.new("http://cosmosrb.com/docs/grapher/")
        parser.parse_file(filename) do |keyword, parameters|
          begin
            # Handle each keyword
            case keyword

            when 'TAB'
              # Expect 0 or 1 parameter
              parser.verify_num_parameters(0, 1, "TAB <Tab Text (optional)>")

              # Add a new tab to the array of tabs
              add_tab(parameters[0])

            when 'PLOT'
              # Expect 1 parameter
              parser.verify_num_parameters(1, 1, "PLOT <Plot Type>")

              # Add a new plot to the current tab
              add_plot(-1, create_plot(parameters[0]))

            when 'DATA_OBJECT'
              # Expect 1 parameter
              parser.verify_num_parameters(1, 1, "DATA_OBJECT <Data Object Type>")

              # Require data object file
              data_object_filename = parameters[0].downcase << '_data_object.rb'
              data_object = Cosmos.require_class(data_object_filename).new
              data_object.plot = @tabs[-1].plots[-1]

              # Add a new data object to the current plot
              @tabs[-1].plots[-1].data_objects << data_object

            else
              # Unknown keywords are passed to the current data object or current plot if there is a current tab
              current_tab = @tabs[-1]
              if current_tab
                current_plot = current_tab.plots[-1]
                if current_plot
                  current_data_object = current_plot.data_objects[-1]
                  if current_data_object
                    current_data_object.handle_keyword(parser, keyword, parameters)
                  else
                    current_plot.handle_keyword(parser, keyword, parameters)
                  end
                else
                  raise ArgumentError, "A PLOT must be defined before using keyword: #{keyword}"
                end
              else
                case keyword
                when 'POINTS_SAVED'
                  # Expect 1 parameter
                  parser.verify_num_parameters(1, 1, "POINTS_SAVED <Points Saved>")

                  # Update Points Saved
                  @points_saved = parameters[0].to_i

                when 'SECONDS_PLOTTED'
                  # Expect 1 parameter
                  parser.verify_num_parameters(1, 1, "SECONDS_PLOTTED <Seconds Plotted>")

                  # Update Seconds Plotted
                  @seconds_plotted = parameters[0].to_f

                when 'POINTS_PLOTTED'
                  # Expect 1 parameter
                  parser.verify_num_parameters(1, 1, "POINTS_PLOTTED <Points Plotted>")

                  # Update Points Plotted
                  @points_plotted = Integer(parameters[0])

                when 'REFRESH_RATE_HZ'
                  # Expect 1 parameter
                  parser.verify_num_parameters(1, 1, "REFRESH_RATE_HZ <Refresh Rate in Hz>")

                  # Update Points Plotted
                  @refresh_rate_hz = parameters[0].to_f
                  raise ArgumentError, "Invalid Refresh Rate Hz: #{@refresh_rate_hz}" if @refresh_rate_hz <= 0.0

                when 'CTS_TIMEOUT'
                  # Expect 1 parameter
                  parser.verify_num_parameters(1, 1, "CTS_TIMEOUT <CTS Timeout in Seconds>")

                  # Update CTS Timeout
                  @cts_timeout = parameters[0].to_f
                  raise ArgumentError, "Invalid CTS Timeout: #{@cts_timeout}" if @cts_timeout <= 0.0

                else
                  # Handle unknown keywords
                  raise ArgumentError, "A TAB must be defined before using keyword: #{keyword}"

                end
              end

            end # case keyword
          rescue Exception => error
            @configuration_errors << error
          end
        end # CosmosConfig.each
      else
        # Use default config of one tab and one plot
        add_tab()
        add_plot(-1, create_plot(@plot_types[0]))
      end

      # Build initial packet to data object mapping
      build_packet_to_data_objects_mapping()

    end # end def initialize

    # Returns the configuration
    def configuration_string
      @mutex.synchronize do
        configuration = ''
        configuration << "SECONDS_PLOTTED #{@seconds_plotted}\n"
        configuration << "POINTS_SAVED #{@points_saved}\n"
        configuration << "POINTS_PLOTTED #{@points_plotted}\n"
        configuration << "REFRESH_RATE_HZ #{@refresh_rate_hz}\n"
        configuration << "CTS_TIMEOUT #{@cts_timeout}\n"
        @tabs.each do |tab|
          configuration << "\n"
          configuration << tab.configuration_string
        end
        configuration
      end
    end

    # Adds a tab to the definition
    def add_tab(tab_text = nil)
      @mutex.synchronize do
        # Add a new tab to the array of tabs
        @tabs << TabbedPlotsTab.new(tab_text)
        @tabs[-1]
      end
    end

    # Removes a tab from the definition
    def remove_tab(tab_index)
      @mutex.synchronize do
        @tabs.delete_at(tab_index)
      end
    end

    # Creates a new plot object
    def create_plot(plot_type, tab_index = -1)
      @mutex.synchronize do
        # Require plot file
        plot_filename = plot_type.downcase << '_plot.rb'
        Cosmos.require_class(plot_filename).new
      end
    end

    # Adds a plot to the definition
    def add_plot(tab_index, plot)
      plot.tab = @tabs[tab_index]
      @tabs[tab_index].plots << plot
    end

    # Removes a plot from the definition
    def remove_plot(tab_index, plot_index)
      @mutex.synchronize do
        @tabs[tab_index].plots.delete_at(plot_index)
      end
    end

    # Adds a data object to the definition
    def add_data_object(tab_index, plot_index, data_object)
      @mutex.synchronize do
        plot = @tabs[tab_index].plots[plot_index]
        data_object.plot = plot
        plot.data_objects << data_object
        build_packet_to_data_objects_mapping()
        plot.redraw_needed = true
        data_object
      end
    end

    # Moves a data object from one index to another
    def move_data_object(tab_index, plot_index, start_index, end_index)
      @mutex.synchronize do
        data_objects = @tabs[tab_index].plots[plot_index].data_objects
        data_objects.insert(end_index, data_objects.delete_at(start_index))
      end
    end

    # Removes a data object from the definition
    def remove_data_object(tab_index, plot_index, data_object_index)
      @mutex.synchronize do
        plot = @tabs[tab_index].plots[plot_index]
        plot.data_objects.delete_at(data_object_index)
        build_packet_to_data_objects_mapping()
        plot.redraw_needed = true
      end
    end

    # Edits a data object in the definition
    def edit_data_object(tab_index, plot_index, data_object_index, edited_data_object)
      data_object = @tabs[tab_index].plots[plot_index].data_objects[data_object_index]
      if data_object.edit_safe?(edited_data_object)
        @mutex.synchronize do
          data_object.edit(edited_data_object)
        end
      else
        replace_data_object(tab_index, plot_index, data_object_index, edited_data_object)
      end
    end

    # Duplicates a data object in the definition and adds it to the definition
    def duplicate_data_object(tab_index, plot_index, data_object_index)
      @mutex.synchronize do
        plot = @tabs[tab_index].plots[plot_index]
        data_object = plot.data_objects[data_object_index]
        plot.data_objects << data_object.copy
        build_packet_to_data_objects_mapping()
        plot.data_objects[-1].plot = plot
        plot.redraw_needed = true
        plot.data_objects[-1]
      end
    end

    # Replaces one data object in the definition with another
    def replace_data_object(tab_index, plot_index, data_object_index, data_object)
      @mutex.synchronize do
        plot = @tabs[tab_index].plots[plot_index]
        data_object.plot = plot
        plot.data_objects[data_object_index] = data_object
        build_packet_to_data_objects_mapping()
        plot.redraw_needed = true
      end
    end

    # Resets each data object
    def reset_data_objects(tab_index = nil, plot_index = nil, data_object_index = nil)
      @mutex.synchronize do
        if data_object_index
          @tabs[tab_index].plots[plot_index].data_objects[data_object_index].reset
        elsif plot_index
          @tabs[tab_index].plots[plot_index].data_objects.each {|data_object| data_object.reset}
        elsif tab_index
          @tabs[tab_index].plots.each {|plot| plot.data_objects.each {|data_object| data_object.reset}}
        else
          @tabs.each {|tab| tab.plots.each {|plot| plot.data_objects.each {|data_object| data_object.reset}}}
        end
      end
    end

    # Exports each data object
    def export_data_objects(progress = nil, tab_index = nil, plot_index = nil, data_object_index = nil)
      columns = []
      @mutex.synchronize do
        tabs = tab_index ? [@tabs[tab_index]] : @tabs
        tabs.each do |tab|
          plots = plot_index ? [tab.plots[plot_index]] : tab.plots
          plots.each do |plot|
            data_objects = data_object_index ? [plot.data_objects[data_object_index]] : plot.data_objects
            data_objects.each do |data_object|
              progress.append_text("Exporting #{data_object.name} on plot '#{plot.title}' on tab '#{tab.tab_text}'") if progress
              columns.concat(data_object.export)
            end
          end
        end
      end
      columns
    end

    # Processes a packet for all data objects that request it
    def process_packet(packet)
      # Increment packet count
      @packet_count += 1

      # Get target name and packet name
      target_name = packet.target_name
      packet_name = packet.packet_name

      # Route packet to its data object(s)
      if target_name and packet_name
        index = target_name + ' ' + packet_name
        @mutex.synchronize do
          data_objects = @packet_to_data_objects_mapping[index]
          process_packet_in_each_data_object(data_objects, packet, @packet_count) if data_objects
        end
      end
    end

    # Updates max points saved in each data object
    def update_max_points_saved(total_points_saved)
      @mutex.synchronize do
        # Count number of data objects
        num_data_objects = 0
        each_data_object {|_| num_data_objects += 1}

        if num_data_objects > 0
          points_saved_per_data_object = total_points_saved / num_data_objects
          points_saved_per_data_object = 1 if points_saved_per_data_object < 1
          each_data_object do |data_object|
            data_object.max_points_saved = points_saved_per_data_object
          end
        end
      end
    end

    # Yields each data object (mutex must already be acquired before calling)
    def each_data_object
      @tabs.each do |tab|
        tab.plots.each do |plot|
          plot.data_objects.each do |data_object|
            yield data_object
          end
        end
      end
    end

    # Takes the mutex protecting the tabbed plot definition
    def mu_synchronize
      @mutex.synchronize do
        yield
      end
    end

    protected

    if RUBY_ENGINE != 'ruby' or ENV['COSMOS_NO_EXT']
      # Optimization method to move each call to C code
      def process_packet_in_each_data_object(data_objects, packet, packet_count)
        data_objects.each do |data_object|
          data_object.process_packet(packet, packet_count)
        end
        return nil
      end
    end

    # Build (or rebuild) the mapping between packets and data objects that process them
    # Note: This is an optimization to prevent looping through all the data objects
    # when each packet is received.
    def build_packet_to_data_objects_mapping
      @packet_to_data_objects_mapping = {}

      @tabs.each do |tab|
        tab.plots.each do |plot|
          plot.data_objects.each do |data_object|
            data_object.processed_packets.each do |target_name, packet_name|
              # Build the index into the hash of the form "TARGET_NAME PACKET_NAME"
              # Note that + is used to create a new object and then << is used to concatenate
              # to the new object.
              if packet_name.casecmp(Telemetry::LATEST_PACKET_NAME).zero?
                packets = System.telemetry.latest_packets(target_name, data_object.item_name)
                packets.each do |packet|
                  index = (packet.target_name + ' ') << packet.packet_name
                  @packet_to_data_objects_mapping[index] ||= []
                  @packet_to_data_objects_mapping[index] << data_object
                end
              else
                index = (target_name + ' ') << packet_name
                @packet_to_data_objects_mapping[index] ||= []
                @packet_to_data_objects_mapping[index] << data_object
              end
            end
          end
        end
      end
    end
  end
end
