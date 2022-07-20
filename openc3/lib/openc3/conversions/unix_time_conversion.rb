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

require 'openc3/conversions/conversion'

module OpenC3
  # Converts a unix format time: Epoch Jan 1 1970, seconds and microseconds
  class UnixTimeConversion < Conversion
    # Initializes the time item to grab from the packet
    #
    # @param seconds_item_name [String] The telemetry item in the packet which
    #   represents the number of seconds since the UNIX time epoch
    # @param microseconds_item_name [String] The telemetry item in the packet
    #   which represents microseconds
    def initialize(seconds_item_name, microseconds_item_name = nil)
      super()
      @seconds_item_name = seconds_item_name
      @microseconds_item_name = microseconds_item_name
    end

    # @param (see Conversion#call)
    # @return [Float] Packet time in seconds since UNIX epoch
    def call(value, packet, buffer)
      if @microseconds_item_name
        return Time.at(packet.read(@seconds_item_name, :RAW, buffer), packet.read(@microseconds_item_name, :RAW, buffer)).sys
      else
        return Time.at(packet.read(@seconds_item_name, :RAW, buffer), 0).sys
      end
    end

    # @return [String] The name of the class followed by the time conversion
    def to_s
      if @microseconds_item_name
        return "Time.at(packet.read('#{@seconds_item_name}', :RAW, buffer), packet.read('#{@microseconds_item_name}', :RAW, buffer)).sys"
      else
        return "Time.at(packet.read('#{@seconds_item_name}', :RAW, buffer), 0).sys"
      end
    end

    # @param (see Conversion#to_config)
    # @return [String] Config fragment for this conversion
    def to_config(read_or_write)
      "    #{read_or_write}_CONVERSION #{self.class.name.class_name_to_filename} #{@seconds_item_name} #{@microseconds_item_name}\n"
    end

    def as_json(*a)
      { 'class' => self.class.name.to_s, 'params' => [@seconds_item_name, @microseconds_item_name] }
    end
  end # class UnixTimeConversion
end
