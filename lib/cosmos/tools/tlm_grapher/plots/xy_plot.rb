# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/tlm_grapher/plots/linegraph_plot'

module Cosmos

  # Represents an X-Y plot
  class XyPlot < LinegraphPlot

    # Manual x scale array of x_min and x_max
    attr_accessor :manual_x_scale

    # Creates a new plot
    def initialize
      super()
      @show_lines = false
      @x_axis_title = nil
      @manual_x_scale = nil
      @unix_epoch_x_values = false
    end # def initialize

    # Handles plot specific keywords
    def handle_keyword(parser, keyword, parameters)
      case keyword
      when 'MANUAL_X_AXIS_SCALE'
        # Expect 2 parameters
        parser.verify_num_parameters(2, 2, "MANUAL_X_AXIS_SCALE <X Min> <X Max>")
        manual_scale = []
        manual_scale[0] = parameters[0].to_f
        manual_scale[1] = parameters[1].to_f
        @manual_x_scale = manual_scale

      else
        # Unknown keywords are passed to parent data object
        super(parser, keyword, parameters)

      end # case keyword

    end # def handle_keyword

    protected

    # Returns the configuration lines used to create this plot
    def plot_configuration_string
      string = super()
      string << "    MANUAL_X_AXIS_SCALE #{@manual_x_scale[0]} #{@manual_x_scale[1]}\n" if @manual_x_scale
      string
    end # def plot_configuration_string

  end # class XyPlot

end # module Cosmos
