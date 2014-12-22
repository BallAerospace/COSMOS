# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/core_ext/cosmos_io'

class IO
  include CosmosIO

  SELECT_BASE_TIMEOUT = 0.0004
  SELECT_MAX_TIMEOUT = 0.016

  def self.fast_select(read_sockets = nil, write_sockets = nil, error_array = nil, timeout = nil)
    # Always try a zero timeout first
    current_timeout = SELECT_BASE_TIMEOUT
    total_timeout = 0.0

    while true
      result = IO.select(read_sockets, write_sockets, error_array, current_timeout)
      return result if result or current_timeout.nil?
      return nil if timeout and total_timeout >= timeout

      if current_timeout <= 0.0001
        # Always try the base timeout next
        current_timeout = SELECT_BASE_TIMEOUT
        total_timeout = SELECT_BASE_TIMEOUT
      else
        # Then start doubling the timeout
        current_timeout = current_timeout * 2

        # Until it is bigger than our max timeout
        if current_timeout >= SELECT_MAX_TIMEOUT
          if timeout
            # Block for the remaining requested timeout
            current_timeout = timeout - total_timeout
            total_timeout = timeout
          else
            # Or block forever
            current_timeout = nil
          end
        else
          # Or it is bigger than the given timeout
          if timeout and current_timeout >= timeout
            # Block for the remaining requested timeout
            current_timeout = timeout - total_timeout
            total_timeout = timeout
          else
            # Up our total time in select
            total_timeout += current_timeout
          end
          if timeout and total_timeout > timeout
            # Block for the remaining requested timeout
            current_timeout = timeout - total_timeout
            total_timeout = timeout
          end
        end
        return nil if current_timeout and current_timeout < 0
      end
    end # while true
  end # fast_select

  def self.fast_read_select(read_sockets, timeout)
    return fast_select(read_sockets, nil, nil, timeout)
  end

  def self.fast_write_select(write_sockets, timeout)
    return fast_select(nil, write_sockets, nil, timeout)
  end
end
