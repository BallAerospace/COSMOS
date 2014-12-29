# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/tlm_viewer/widgets/widget'
require 'cosmos/tools/tlm_viewer/widgets/layout_widget'

module Cosmos

  class MatrixbycolumnsWidget < Qt::GridLayout
    include Widget
    include LayoutWidget

    def initialize(parent_layout, num_columns, hSpacing = 0, vSpacing = 0)
      super()
      @num_columns = num_columns.to_i
      @row = 0
      @column = 0
      parent_layout.addLayout(self) if parent_layout
    end

    def addLayout(layout_to_add)
      super(layout_to_add, @row, @column)
      @column += 1
      if @column >= @num_columns
        @row += 1
        @column = 0
      end
    end

    def addWidget(widget_to_add)
      super(widget_to_add, @row, @column)
      @column += 1
      if @column >= @num_columns
        @row += 1
        @column = 0
      end
    end
  end

end # module Cosmos
