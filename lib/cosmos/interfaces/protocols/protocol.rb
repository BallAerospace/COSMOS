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

    def initialize
      @interface = nil
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

    def read_data(data)
      return data, nil
    end

    def read_packet(packet)
      return packet, nil
    end

    def write_packet(packet)
      return packet, nil
    end

    def write_data(data)
      return data, nil
    end

    def post_write_interface(packet, data)
      return packet, data, nil
    end
  end
end
