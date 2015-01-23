# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  class Sleeper
    def initialize
      @pipe_reader, @pipe_writer = IO.pipe
      @readers = [@pipe_reader]
      @canceled = false
    end

    def sleep(seconds)
      read_ready, _ = IO.select(@readers, nil, nil, seconds)
      if read_ready && read_ready.include?(@pipe_reader)
        return true
      else
        return false
      end
    end

    def cancel
      if !@canceled
        @canceled = true
        @pipe_writer.write('.')
      end
    end
  end

end # module Cosmos
