# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  # Holds a cmd/tlm pair of packet log writers
  class PacketLogWriterPair

    # @return [PacketLogWriter] The comamnd log writer
    attr_reader :cmd_log_writer
    # @return [PacketLogWriter] The telemetry log writer
    attr_reader :tlm_log_writer

    # @param cmd_log_writer [PacketLogWriter] The command log writer
    # @param tlm_log_writer [PacketLogWriter] The telemetry log writer
    def initialize(cmd_log_writer, tlm_log_writer)
      @cmd_log_writer = cmd_log_writer
      @tlm_log_writer = tlm_log_writer
    end

  end # class PacketLogWriterPair

end # module Cosmos
