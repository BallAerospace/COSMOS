# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/qt_tool'
require 'cosmos/gui/line_graph/line_graph_dialog'

def plot(x, y1, y2 = nil)
  Qt.execute_in_main_thread do
    a = Cosmos::LineGraphDialog.new('Graph')
    a.line_graph.add_line('Data 1', y1, x, nil, nil, nil, nil, 'red')
    if y2
      a.line_graph.add_line('Data 2', y2, x, nil, nil, nil, nil, 'blue')
    end
    a.raise
    a.exec
    a.dispose
  end
end
