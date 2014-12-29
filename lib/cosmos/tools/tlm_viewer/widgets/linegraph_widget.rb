# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/tlm_viewer/widgets/widget'
require 'cosmos/gui/line_graph/line_graph'

module Cosmos

  class LinegraphWidget < LineGraph
    include Widget

    def initialize(parent_layout, target_name, packet_name, item_name, num_samples = 100, width = 300, height = 200, value_type = :CONVERTED)
      super(target_name, packet_name, item_name, value_type)
      setFixedSize(width.to_i, height.to_i)
      self.title = "#{@target_name} #{@packet_name} #{@item_name}"
      self.show_y_grid_lines = true
      self.unix_epoch_x_values = false
      @num_samples = num_samples.to_i
      @data = []
      parent_layout.addWidget(self) if parent_layout
    end

    def self.takes_value?
      return true
    end

    def value=(data)
      @data << data.to_f

      if @data.length > @num_samples
        @data = @data[1..-1]
      end
      if not @data.empty?
        self.clear_lines
        self.add_line('line', @data)
        self.graph
      end
    end
  end

  # Disable tooltip so that graph can be moused-over
  def get_tooltip_text
    return nil
  end

end # module Cosmos
