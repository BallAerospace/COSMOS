# encoding: ascii-8bit

# Copyright 2017 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/interfaces/interface'

module Cosmos
  # Base class for interfaces that act read and write from a stream
  class StreamInterface < Interface
    attr_accessor :stream

    def initialize(stream_protocol_type = nil, stream_protocol_args = [])
      super()
      @stream_protocol_type = ConfigParser::handle_nil(stream_protocol_type)
      @stream_protocol_args = stream_protocol_args
      if @stream_protocol_type
        stream_protocol_class_name = stream_protocol_type.to_s.capitalize << 'StreamProtocol'
        klass = Cosmos.require_class(stream_protocol_class_name.class_name_to_filename)
        add_protocol(klass, stream_protocol_args, :READ_WRITE)
      end
    end

    def connect
      super()
      @stream.connect if @stream
    end

    def connected?
      if @stream
        @stream.connected?
      else
        false
      end
    end

    def disconnect
      @stream.disconnect if @stream
      super()
    end

    def read_interface
      begin
        data = @stream.read
      rescue Timeout::Error
        Logger.instance.error "Timeout waiting for data to be read"
        data = nil
      end
      return nil if data.nil? or data.length <= 0
      read_interface_base(data)
      data
    end

    def write_interface(data)
      write_interface_base(data)
      @stream.write(data)
    end
  end
end
