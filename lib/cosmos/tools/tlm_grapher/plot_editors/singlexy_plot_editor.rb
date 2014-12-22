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
require 'cosmos/tools/tlm_grapher/plot_editors/xy_plot_editor'
require 'cosmos/tools/tlm_grapher/plots/singlexy_plot'

module Cosmos

  # Widget which contains the X-Y plot for editing
  class SinglexyPlotEditor < XyPlotEditor

    def initialize(parent, plot = nil)
      plot = SinglexyPlot.new unless plot
      super(parent, plot)
    end

  end # class SinglexyPlotEditor

end # module Cosmos
