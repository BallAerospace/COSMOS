# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/conversions/conversion'
require 'cosmos/packet_logs'
require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server'

module Cosmos

  # Creates new packet logs whenever it executes
  class NewPacketLogConversion < Conversion

    # Initializes converted_type to :FLOAT and converted_bit_size to 64
    #
    # @param packet_log_writer_name [String] Name of the packet log writer to start new logs on
    def initialize(packet_log_writer_name = 'ALL')
      super()
      @packet_log_writer_name = packet_log_writer_name
    end

    # @param (see Conversion#call)
    # @return [Varies] The value given
    def call(value, packet, buffer)
      if CmdTlmServer.instance and CmdTlmServer.packet_logging
        CmdTlmServer.instance.start_logging(@packet_log_writer_name)
      end
      value
    end

    # @return [String] The name of the class and the associated packet log writer name
    def to_s
      result = super()
      result << " (#{@packet_log_writer_name})"
      result
    end

    # @param (see Conversion#to_config)
    # @return [String] Config fragment for this conversion
    def to_config(read_or_write)
      "    #{read_or_write}_CONVERSION #{self.class.name.class_name_to_filename} #{@packet_log_write_name}\n"
    end

    def as_json
      { 'class' => self.class.name.to_s, 'params' => [@packet_log_write_name] }
    end

  end # class NewPacketLogConversion

end # module Cosmos
