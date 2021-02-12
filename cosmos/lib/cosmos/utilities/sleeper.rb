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

module Cosmos

  # Allows for a breakable sleep implementation using the self-pipe trick
  # See http://www.sitepoint.com/the-self-pipe-trick-explained/
  class Sleeper
    def initialize
      @pipe_reader, @pipe_writer = IO.pipe
      @readers = [@pipe_reader]
      @canceled = false
    end

    # Breakable version of sleep
    # @param seconds Number of seconds to sleep
    # @return true if the sleep was broken by someone calling cancel
    #   otherwise returns false
    def sleep(seconds)
      read_ready, _ = IO.select(@readers, nil, nil, seconds)
      if read_ready && read_ready.include?(@pipe_reader)
        return true
      else
        return false
      end
    end

    # Break sleeping - Once canceled a sleeper cannot be used again
    def cancel
      if !@canceled
        @canceled = true
        @pipe_writer.write('.')
      end
    end
  end

end # module Cosmos
