# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the XyPlotEditor class.   This class
# provides dialog box content to create/edit xy plots.

require 'cosmos'
require 'cosmos/tools/tlm_grapher/plot_editors/linegraph_plot_editor'
require 'cosmos/tools/tlm_grapher/plots/xy_plot'

module Cosmos

  # Widget which contains the X-Y plot for editing
  class XyPlotEditor < LinegraphPlotEditor

    def initialize(parent, plot = nil)
      plot = XyPlot.new unless plot
      super(parent, plot)

      # Float Choosers for Manual Scaling
      manual_x_scale_min = nil
      manual_x_scale_min = plot.manual_x_scale[0] if plot.manual_x_scale
      @manual_x_scale_min  = FloatChooser.new(self, 'Manual X Axis Minimum:', manual_x_scale_min.to_s)
      @layout.addWidget(@manual_x_scale_min)
      manual_x_scale_max = nil
      manual_x_scale_max = plot.manual_x_scale[1] if plot.manual_x_scale
      @manual_x_scale_max  = FloatChooser.new(self, 'Manual X Axis Maximum:', manual_x_scale_max.to_s)
      @layout.addWidget(@manual_x_scale_max)
    end

    # Returns the edited plot
    def plot
      plot = super()
      manual_x_scale_max = @manual_x_scale_max.string.strip
      manual_x_scale_min = @manual_x_scale_min.string.strip
      if not manual_x_scale_max.empty? or not manual_x_scale_min.empty?
        if manual_x_scale_max.to_f > manual_x_scale_min.to_f
          plot.manual_x_scale = [manual_x_scale_min.to_f, manual_x_scale_max.to_f]
        elsif manual_x_scale_min.to_f > manual_x_scale_max.to_f
          plot.manual_x_scale = [manual_x_scale_max.to_f, manual_x_scale_min.to_f]
        else
          plot.manual_x_scale = nil
        end
      else
        plot.manual_x_scale = nil
      end
      plot
    end

  end # class XyPlotEditor

end # module Cosmos
