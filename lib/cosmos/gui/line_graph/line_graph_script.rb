# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
Qt.execute_in_main_thread do
  require 'cosmos/gui/qt_tool'
  require 'cosmos/gui/line_graph/line_graph_dialog'
end

# Create a new graph object and populate
# plot (x, y, legend, [y,legend], [y,legend], ... , [opts])
#   x           - default => [0...y_array.length]
#   y           - Y data array to plot
#   legend      - Line Legend to describe Y data
#   args        - Additional y , legend pairs to plot
#   opts        - Hash options at the end of the argument list
#    :width => 400    - default => 800
#    :height => 300   - default => 600
#    :x => 100        - default => -1 # Place centered in current screen
#    :y => 100        - default => -1 # Place centered in current screen
#    :winTitle => "Graph 1" - default => "Graph"
def plot (x = nil, y = nil, legend = "Line 1", *args)
  my_opts = {:width => 800, :height => 600, :x => -1, :y => -1, :winTitle => "Graph"}

  # Get the Hash options parameters from the end of the list of arguments
  arg_idx = -1
  while (args[arg_idx].is_a?(Hash)) do
    my_opts.merge!(args[arg_idx])
    arg_idx -= 1
  end

  if y
    raise "Legend [0] must be a string" unless legend.kind_of? String
    raise "Y [0] must be an array" unless y.kind_of? Array
  end

  # Split out the arguments for the other y arrays & legends
  y_array = args[0..arg_idx].values_at(* args[0..arg_idx].each_index.select {|i| i.even?})
  legend_array = args[0..arg_idx].values_at(* args[0..arg_idx].each_index.select {|i| i.odd?})

  raise "Legend Argument List and Y Argument List not the same size" unless legend_array.length == y_array.length
  (0...y_array.length).each do |i|
    if y_array[i]
      raise "Legend [#{i+1}] must be a string" unless legend_array[i].kind_of? String
      raise "Y [#{i+1}] must be an array" unless y_array[i].kind_of? Array
    end
  end

  my_line_graph = ''
  Qt.execute_in_main_thread do
    a = Cosmos::LineGraphDialog.new(my_opts[:winTitle], my_opts[:width], my_opts[:height])
    if y
      a.line_graph.add_line(legend, y, x, nil, nil, nil, nil, 'auto')
    end
    
    (0...y_array.length).each do |i|
      if y_array[i]
        a.line_graph.add_line(legend_array[i], y_array[i], x, nil, nil, nil, nil, 'auto')
      end
    end

    a.raise
    a.show

    my_line_graph = a.line_graph

    # Move the window
    if my_opts[:x] >= 0 && my_opts[:y] >= 0
      a.move(my_opts[:x],my_opts[:y])
    end
  end
  return my_line_graph
end

