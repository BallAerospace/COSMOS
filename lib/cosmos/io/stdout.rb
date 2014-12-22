# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/io/io_multiplexer'

module Cosmos

  # Adds STDOUT to the multiplexed streams
  class Stdout < IoMultiplexer
    @@instance = nil

    def initialize
      super()
      @streams << STDOUT
      @@instance = self
    end

    # @return [Stdout] Returns a single instance of Stdout
    def self.instance
      self.new unless @@instance
      @@instance
    end

    def tty?
      false
    end
  end

end
