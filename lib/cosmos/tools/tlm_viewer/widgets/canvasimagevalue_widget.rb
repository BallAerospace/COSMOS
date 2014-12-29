# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the CanvasimagevalueWidget class.  This
# widget displays one of two images within a CanvasWidget.  The image displayed
# is either '[filename]on.gif' or '[filename]off.gif' depending on the
# telemetry point value of 1 or 0 respectively.

require 'cosmos/tools/tlm_viewer/widgets/canvasvalue_widget'

module Cosmos

  class CanvasimagevalueWidget < CanvasvalueWidget

    def initialize(parent_layout, target_name, packet_name, item_name, filename, x, y, value_type=:RAW)
      super(parent_layout, target_name, packet_name, item_name, value_type)
      @x = x.to_i
      @y = y.to_i
      @imageOn = nil
      @imageOff = nil

      filenameOn = File.join(::Cosmos::USERPATH, 'config', 'data', filename+'on.gif')
      unless File.exist?(filenameOn)
        raise "Can't find the file #{filenameOn} in #{::Cosmos::USERPATH}/config/data"
      end
      @imageOn = Qt::Image.new(filenameOn)

      filenameOff = File.join(::Cosmos::USERPATH, 'config', 'data', filename+'off.gif')
      unless File.exist?(filenameOff)
        raise "Can't find the file #{filenameOff} in #{::Cosmos::USERPATH}/config/data"
      end
      @imageOff = Qt::Image.new(filenameOff)
    end

    def draw_widget(painter, on_value)
      if on_value
        painter.drawImage(@x, @y, @imageOn) if @imageOn
      else
        painter.drawImage(@x, @y, @imageOff) if @imageOff
      end
    end

    def dispose
      super()
      @imageOn.dispose
      @imageOff.dispose
    end
  end

end # module Cosmos
