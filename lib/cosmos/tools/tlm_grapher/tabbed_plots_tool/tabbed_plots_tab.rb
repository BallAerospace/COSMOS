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

  # Represents a tab in a tabbed plots definition
  class TabbedPlotsTab

    # Text to display in a tab
    attr_accessor :tab_text

    # Array of plots in the tab
    attr_accessor :plots

    # Gui object for tab item
    attr_accessor :gui_item

    # Gui object for tab frame
    attr_accessor :gui_frame

    # Gui object for tab layout
    attr_accessor :gui_layout

    # Create a new TabbedPlotsTab
    def initialize(tab_text = nil)
      @tab_text = tab_text
      @plots = []
      @gui_item = nil
      @gui_frame = nil
      @gui_layout = nil
    end # def initialize

    # Returns the configuration lines used to create this tab
    def configuration_string
      if @tab_text
        string = "TAB \"#{@tab_text}\"\n"
      else
        string = "TAB\n"
      end
      @plots.each do |plot|
        string << plot.configuration_string
      end
      string
    end # def configuration_string

  end # class TabbedPlotsTab

end # module Cosmos
