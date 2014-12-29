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

  # Widget which contains the plot for editing
  class PlotEditor < Qt::Widget

    # Overall frame for this plot type
    attr_accessor :plot

    def initialize(parent, plot)
      super(parent)
      @plot = plot
    end
  end # class PlotEditor

end # module Cosmos
