# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/tlm_grapher/plot_gui_objects/xy_plot_gui_object'

module Cosmos

  # Represents a single X-Y graph plot in the graphing system. This class
  # extends XyPlotGuiObject by re-implementing update_plot.
  class SinglexyPlotGuiObject < XyPlotGuiObject

    # Updates the lines on the plot
    def update_plot(points_plotted, min_x_value, max_x_value)
      super(points_plotted, min_x_value, max_x_value, true)
    end

  end # class SinglexyPlotGuiObject

end # module Cosmos
