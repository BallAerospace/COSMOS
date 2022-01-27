# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
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

require 'cosmos/config/config_parser'
require 'thread'

module Cosmos
  # Base class for all COSMOS protocols which defines a framework which must be
  # implemented by a subclass.
  class Protocol
    attr_accessor :interface
    attr_accessor :allow_empty_data

    # @param allow_empty_data [true/false/nil] Whether or not this protocol will allow an empty string
    # to be passed down to later Protocols (instead of returning :STOP). Can be true, false, or nil, where
    # nil is interpreted as true unless the Protocol is the last Protocol of the chain.
    def initialize(allow_empty_data = nil)
      @interface = nil
      @allow_empty_data = ConfigParser.handle_true_false_nil(allow_empty_data)
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
      if data.length <= 0
        if @allow_empty_data.nil?
          if @interface and @interface.read_protocols[-1] == self
            # Last read interface in chain with auto @allow_empty_data
            return :STOP
          end
        elsif !@allow_empty_data
          # Don't @allow_empty_data means STOP
          return :STOP
        end
      end
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
