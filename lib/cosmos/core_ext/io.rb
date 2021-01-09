# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'cosmos/core_ext/kernel'
require 'cosmos/core_ext/cosmos_io'

class IO
  include CosmosIO

  # Initial timeout to call IO.select with. Timeouts are increased by doubling
  # this value until the SELET_MAX_TIMEOUT value is reached.
  SELECT_BASE_TIMEOUT = 0.0004
  # The maximum timeout at which point we call IO.select with whatever
  # remaining timeout is left.
  SELECT_MAX_TIMEOUT = 0.016

  class << self

    # Alias the original IO.select method
    alias_method :__select__, :select

    # On Windows the IO.select function (when called with no timeout) takes
    # a minimum of 10 msec to return, even if one of the IO objects is
    # ready to read/write sooner than that.
    #
    # This method is identical to IO.select but instead of calling IO.select with
    # the full timeout, it calls IO.select with a small timeout and then
    # doubles the timeout twice until eventually it calls IO.select with the
    # remaining passed in timeout value.
    #
    # @param read_sockets [Array<IO>] IO objects to wait to be ready to read
    # @param write_sockets [Array<IO>] IO objects to wait to be ready to write
    # @param error_array [Array<IO>] IO objects to wait for exceptions
    # @param timeout [Numeric] Number of seconds to wait
    def fast_select(read_sockets = nil, write_sockets = nil, error_array = nil, timeout = nil)
      # Always try a zero timeout first
      current_timeout = SELECT_BASE_TIMEOUT
      total_timeout = 0.0

      while true
        result = IO.__select__(read_sockets, write_sockets, error_array, current_timeout)
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

    # For non-windows systems, leave IO.select alone, but for windows
    # monkey-patch IO.select to use our fast-select implementation.
    if Kernel.is_windows?
      def select(read_sockets = nil, write_sockets = nil, error_array = nil, timeout = nil)
        return fast_select(read_sockets, write_sockets, error_array, timeout)
      end
    end

    # @param read_sockets [Array<IO>] IO objects to wait to be ready to read
    # @param timeout [Numeric] Number of seconds to wait
    def fast_read_select(read_sockets, timeout)
      return fast_select(read_sockets, nil, nil, timeout)
    end

    # @param write_sockets [Array<IO>] IO objects to wait to be ready to write
    # @param timeout [Numeric] Number of seconds to wait
    def fast_write_select(write_sockets, timeout)
      return fast_select(nil, write_sockets, nil, timeout)
    end
  end

  # Alias the original close method
  alias_method :__close__, :close

  # Patch the close method so that it won't raise any exceptions
  def close
    begin
      __close__
    rescue
    end
  end
end
