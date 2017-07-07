# encoding: ascii-8bit

# Copyright 2017 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/config/config_parser'
require 'cosmos/interfaces/protocols/protocol'
require 'thread'

module Cosmos
  class Protocol
    attr_accessor :interface
    attr_accessor :allow_empty_data

    # @param allow_empty_data [true/false] Whether STOP should be returned on empty data
    def initialize(allow_empty_data = false)
      @interface = nil
      @allow_empty_data = ConfigParser.handle_true_false(allow_empty_data)
      reset()
    end

    def reset
    end

    def connect_reset
      reset()
    end

    def disconnect_reset
      reset()
    end

    # Ensure we have some data in case this is the only protocol
    def read_data(data)
      return :STOP if (data.length <= 0) && !@allow_empty_data
      data
    end

    def read_packet(packet)
      return packet
    end

    def write_packet(packet)
      return packet
    end

    def write_data(data)
      return data
    end

    def post_write_interface(packet, data)
      return packet, data
    end
  end
end
