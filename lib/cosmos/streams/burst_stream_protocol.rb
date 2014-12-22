# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/streams/stream_protocol'

module Cosmos

  # Reads all data available in the stream and creates a packet
  # with that data.
  class BurstStreamProtocol < StreamProtocol
    # This class is currently empty because StreamProtocol performs all
    # the necessary functionality. It exists because of the way
    # {StreamInterface} creates the stream protocol by appending
    # 'StreamProtocol' to the name of the protocol. Thus we need a
    # BurstStreamProtocol so 'burst' can be used by the {StreamInterface}.
  end

end # module Cosmos
