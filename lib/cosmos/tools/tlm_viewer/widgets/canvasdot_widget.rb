# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/tlm_viewer/widgets/widget'

module Cosmos

  class CanvasdotWidget
    include Widget
    
    def initialize(parent_layout, x, y, color='black', width=3)
      super()
      if is_numeric?(x)
        @x = x.to_i
      else
        @x = x.to_s
      end
    
      if is_numeric?(y)
        @y = y.to_i
      else
        @y = y.to_s
      end
    
      @point = Qt::Point.new(0, 0)
      update_point
    
      @width = width.to_i
      @color = Cosmos::getColor(color)
      parent_layout.add_repaint(self)
    end # initialize
    
    def update_point
      if is_numeric?(@x)
        @point.x = @x
      else
        @point.x = eval_str(@x)
      end
      
      if is_numeric?(@y)
        @point.y = @y
      else
        @point.y = eval_str(@y)
      end
    end # update_point
  
    def is_numeric?(obj) 
      obj.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/) == nil ? false : true
    end

    def paint(painter)
      painter.save
      painter.setBrush(@color)
      painter.drawEllipse(@point, @width, @width)
      painter.restore
    end
  
    def eval_str(string_to_eval)
      @screen.instance_eval(string_to_eval)
    end
  
    def update_widget
      update_point
    end

    def dispose
      super()
      @point.dispose
    end
  end # CanvasdotWidget

end # module Cosmos
