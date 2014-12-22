# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'

module Cosmos

  # Represents a plot
  class Plot

    # Tab containing this plot
    attr_accessor :tab

    # Array of data objects in the plot
    attr_accessor :data_objects

    # GUI object associated with this plot
    attr_accessor :gui_object

    # Type of plot
    attr_accessor :plot_type

    # Flag to indicate if plot redraw is needed
    attr_accessor :redraw_needed

    # Creates a new Plot
    def initialize
      @tab = nil
      @data_objects = []
      @gui_object = nil
      @redraw_needed = false

      # Type is classname without Plot
      @plot_type = self.class.to_s[0..-5].upcase
      @plot_type = @plot_type.split("::")[-1] # Remove Cosmos:: if present
    end # def initialize

    # Returns the configuration lines used to create this plot
    def configuration_string
      string = "  PLOT #{@plot_type}\n"
      string << plot_configuration_string()
      @data_objects.each do |data_object|
        string << data_object.configuration_string
      end
      string
    end # def configuration_string

    # Handles plot specific keywords
    def handle_keyword(parser, keyword, parameters)
      raise ArgumentError, "Unknown keyword received by #{self.class}: #{keyword}"
    end # def handle_keyword

    protected

    # Plot specific configuration string
    def plot_configuration_string
      return ''
    end

  end # class Plot

end # module Cosmos
