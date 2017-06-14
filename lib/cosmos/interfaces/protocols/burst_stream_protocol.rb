# encoding: ascii-8bit

# Copyright 2017 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/interfaces/protocols/stream_protocol'

module Cosmos
  # Reads all data available in the stream and creates a packet
  # with that data.
  module BurstStreamProtocol
    include StreamProtocol
    # This class is currently empty because StreamProtocol performs all
    # the necessary functionality. It exists because of the way
    # {StreamInterface} creates the stream protocol by appending
    # 'StreamProtocol' to the name of the protocol. Thus we need a
    # BurstStreamProtocol so 'burst' can be used by the {StreamInterface}.

    # Set procotol specific options
    # @param procotol [String] Name of the procotol
    # @param params [Array<Object>] Array of parameter values
    def configure_protocol(protocol, params)
      super(protocol, params)
      configure_stream_protocol(*params) if protocol == 'BurstStreamProtocol'
    end
  end
end # module Cosmos
