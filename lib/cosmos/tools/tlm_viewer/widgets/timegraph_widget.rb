# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'time'
require 'cosmos/tools/tlm_viewer/widgets/linegraph_widget'
require 'cosmos/script'

module Cosmos

  # TimegraphWidget class
  #
  # This class creates a graph of the supplied data value versus time.
  class TimegraphWidget < LinegraphWidget

    def initialize(parent_layout, target_name, packet_name, item_name, num_samples = 100, width = 300, height = 200, point_size = 5, time_item_name = 'RECEIVED_TIMESECONDS', value_type = :CONVERTED)
      super(parent_layout, target_name, packet_name, item_name, num_samples, width, height, value_type)
      @time_item_name = time_item_name.to_s
      @time = []
      @first_value = true
      @initial_time = 0
      @vs_time = true
      @items = []
      @items << [@target_name, @packet_name, @item_name]
      @items << [@target_name, @packet_name, @time_item_name]
      self.show_y_grid_lines = true
      self.unix_epoch_x_values = true
      self.point_size = Integer(point_size)
    end

    # Obtains the telemetry item data and it's corresponding time stamp from
    # the telemetry item name set during widget creation and then adds this
    # data to the LineGraph object.
    def value=(data)
      data  = nil
      t_sec = nil

      if @screen.mode == :REALTIME
        begin
          # Even though it has been provided, need to get data and timestamp here.
          # Otherwise, the time stamp may be from a different packet if packets
          # are received too fast
          tlm_items, _, _, _ = get_tlm_values(@items)
          data = tlm_items[0]
          t_sec = tlm_items[1]
          return if t_sec == 0.0 # Don't graph if we have no timestamp
        rescue DRb::DRbConnError
          # If the cts is not available, it must have just recently been lost
          # simply return without updating.
          return
        end
      else # in log mode
        # Note: in logmode value= usually isn't called with every data point so this is never
        # going to work very well.  Will work ok for logfile playback so we will
        # still support it.
        data = System.telemetry.value(@target_name, @packet_name, @item_name)
        t_sec = System.telemetry.value(@target_name, @packet_name, @time_item_name)
      end

      # Don't regraph old data
      return if @time[-1] == t_sec

      # create time array
      @time << t_sec

      # create data array and graph
      @data << data.to_f

      # truncate data if necessary
      if @data.length > @num_samples
        @data = @data[1..-1]
        @time = @time[1..-1]
      end

      self.clear_lines
      self.add_line('line', @data, @time)
      self.graph
    end

  end

end # module Cosmos
