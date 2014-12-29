# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/io/io_multiplexer'

module Cosmos

  # Adds STDERR to the multiplexed streams
  class Stderr < IoMultiplexer
    @@instance = nil

    def initialize
      super()
      @streams << STDERR
      @@instance = self
    end

    # @return [Stderr] Returns a single instance of Stderr
    def self.instance
      self.new unless @@instance
      @@instance
    end

    def tty?
      false
    end
  end

end
