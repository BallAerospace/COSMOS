# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
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

require 'cosmos/interfaces/interface'
require 'cosmos/io/json_drb_object'
require 'cosmos/utilities/sleeper'

module Cosmos

  # Defines all the attributes and methods common to all interface classes
  # used by COSMOS.
  class DartStatusInterface < Interface
    # Initialize default attribute values
    def initialize(query_period = 20.0)
      super()
      @write_raw_allowed = false
      @dart = nil
      @first = true
      @query_period = query_period.to_f
      @query_time = nil
    end

    # Connects the interface to its target(s). Must be implemented by a
    # subclass.
    def connect
      super()
      @first = true
      @status_packet = System.telemetry.packet('DART', 'STATUS').clone
      @status_packet.write('PACKET_ID', 1)
      @clear_errors_command = System.commands.packet('DART', 'CLEAR_ERRORS')
      @sleeper = Sleeper.new
      @dart = JsonDRbObject.new(System.connect_hosts['DART_DECOM'], System.ports['DART_DECOM'])
    end

    # Indicates if the interface is connected to its target(s) or not. Must be
    # implemented by a subclass.
    def connected?
      if @dart
        true
      else
        false
      end
    end

    # Disconnects the interface from its target(s). Must be implemented by a
    # subclass.
    def disconnect
      super()
      @sleeper.cancel
      @dart.disconnect if @dart
      @dart = nil
    end

    def read_interface
      canceled = false
      unless @first
        if @query_time
          sleep_time = @query_period - (Time.now - @query_time)
          canceled = @sleeper.sleep(sleep_time) if sleep_time > 0
        end
        @query_time = Time.now
      end
      @first = false
      unless canceled
        data = @dart.dart_status
        write_interface_base(@dart.request_data.to_s)
        read_interface_base(@dart.response_data.to_s)
        data.each do |key, value|
          @status_packet.write(key, value)
        end
        return @status_packet.buffer
      else
        return nil
      end
    end

    def write_interface(data)
      @dart.clear_errors
      write_interface_base(@dart.request_data.to_s)
      read_interface_base(@dart.response_data.to_s)
      return nil
    end
  end
end
