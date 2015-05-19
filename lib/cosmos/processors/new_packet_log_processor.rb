# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/processors/processor'

module Cosmos

  class NewPacketLogProcessor < Processor

    # @param packet_log_writer_name [String] Name of the packet log writer to start new logs on
    def initialize(packet_log_writer_name = 'ALL')
      super()
      @packet_log_writer_name = packet_log_writer_name
    end

    # Create a new log file
    #
    # See Processor#call
    def call(packet, buffer)
      if CmdTlmServer.instance and $0 !~ /Replay/
        CmdTlmServer.instance.start_logging(@packet_log_writer_name)
      end
    end

  end # class NewPacketLogProcessor

end # module Cosmos
