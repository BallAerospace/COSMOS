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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'openc3/interfaces/interface'

module OpenC3
  # Base class for interfaces that act read and write from a stream
  class StreamInterface < Interface
    attr_accessor :stream

    def initialize(protocol_type = nil, protocol_args = [])
      super()
      @stream = nil
      @protocol_type = ConfigParser.handle_nil(protocol_type)
      @protocol_args = protocol_args
      if @protocol_type
        protocol_class_name = protocol_type.to_s.capitalize << 'Protocol'
        klass = OpenC3.require_class(protocol_class_name.class_name_to_filename)
        add_protocol(klass, protocol_args, :READ_WRITE)
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
      timeout = false
      begin
        data = @stream.read
      rescue Timeout::Error
        Logger.error "#{@name}: Timeout waiting for data to be read"
        timeout = true
        data = nil
      end
      if data.nil? or data.length <= 0
        Logger.info "#{@name}: #{@stream.class} read returned nil" if data.nil? and not timeout
        Logger.info "#{@name}: #{@stream.class} read returned 0 bytes (stream closed)" if not data.nil? and data.length <= 0
        return nil
      end

      read_interface_base(data)
      data
    end

    def write_interface(data)
      write_interface_base(data)
      @stream.write(data)
    end
  end
end
