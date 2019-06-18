# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
Cosmos.catch_fatal_exception do
  require 'cosmos/tools/tlm_grapher/tabbed_plots_tool/tabbed_plots_tool'
  require 'cosmos/tools/tlm_grapher/data_objects/housekeeping_data_object'
end

module Cosmos

  # Telemetry Grapher displays multiple line graphs that perform various
  # analysis on housekeeping telemetry.
  class TlmGrapher < TabbedPlotsTool

    # Runs the application
    def self.run(opts = nil, options = nil)
      Cosmos.catch_fatal_exception do
        unless options
          opts, options = create_default_options()
          options.auto_size = false
          options.width = 1000
          options.height = 800
          options.title = "Telemetry Grapher"
          options.tool_short_name = 'tlmgrapher'
          options.tabbed_plots_type = 'overview'
          options.data_object_types = ['HOUSEKEEPING', 'XY','SINGLEXY']
          options.plot_types = ['LINEGRAPH', 'XY','SINGLEXY']
          options.plot_type_to_data_object_type_mapping = {'LINEGRAPH' => ['HOUSEKEEPING'], 'XY' => ['XY'], 'SINGLEXY' => ['SINGLEXY']}
          options.adder_types = ['HOUSEKEEPING']
          options.adder_orientation = Qt::Horizontal
          options.items = []
          options.start = false
          options.replay = false
          options.about_string = "TlmGrapher provides realtime and log file graphing abilities to the COSMOS system."

          opts.separator "Telemetry Grapher Specific Options:"
          opts.on("-s", "--start", "Start graphing immediately") do |arg|
            options.start = true
          end
          opts.on("-i", "--item 'TARGET_NAME PACKET_NAME ITEM_NAME'", "Start graphing the specified item (ignores config file)") do |arg|
            split = arg.split
            if split.length != 3
              puts "Items must be specified as 'TARGET_NAME PACKET_NAME ITEM_NAME' in quotes"
              exit
            end
            options.items << split
          end
          opts.on("--replay", "Start Telemetry Grapher in Replay mode") do
            options.replay = true
          end
        end

        super(opts, options)
      end
    end

    def closeEvent(event)
      super(event)
    end

    # Handles items being passed in as command line arguments
    def handle_items
      plot_index = 0
      @items.each do |target_name, packet_name, item_name|
        target_name.upcase!
        packet_name.upcase!
        item_name.upcase!
        # Check to see if the item name is followed by an array index,
        # notated by square brackets around an integer; i.e. ARRAY_ITEM[1]
        if (item_name =~ /\[\d+\]$/)
          # We found an array index.
          # The $` special variable is the string before the regex match, i.e. ARRAY_ITEM
          item_name = $`
          # The $& special variable is the string matched by the regex, i.e. [1].
          # Strip off the brackets and then convert the array index to an integer.
          item_array_index = $&.gsub(/[\[\]]/, "").to_i
        else
          item_array_index = nil
        end
        # Default configuration has one plot so don't add plot for first item
        data_object = HousekeepingDataObject.new
        data_object.set_item(target_name, packet_name, item_name)
        data_object.item_array_index = item_array_index
        @tabbed_plots_config.add_data_object(0, 0, data_object)
        plot_index += 1
      end
    end
  end
end
