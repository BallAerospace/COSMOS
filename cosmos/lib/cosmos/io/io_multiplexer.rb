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

module Cosmos
  # Adds IO streams and then defers to the streams when using any of the Ruby
  # output methods such as print, puts, etc.
  class IoMultiplexer
    # Create the empty stream array
    def initialize
      @streams = []
    end

    def write(*args)
      first = true
      result = nil
      @streams.each do |stream|
        if first
          result = stream.write(*args)
          result = self if result == stream
          first = false
        else
          stream.write(*args)
        end
      end
      result
    end

    # Forwards IO methods to all streams
    def method_missing(method_name, *args)
      first = true
      result = nil
      @streams.each do |stream|
        if first
          # Fortify Access Specifier Manipulation
          # We're forwarding only public methods to the stream
          result = stream.public_send(method_name, *args)
          result = self if result == stream
          first = false
        else
          # Fortify Access Specifier Manipulation
          # We're forwarding only public methods to the stream
          stream.public_send(method_name, *args)
        end
      end
      result
    end

    # Removes STDOUT and STDERR from the array of streams
    def remove_default_io
      @streams.delete(STDOUT)
      @streams.delete(STDERR)
    end

    # @param stream [IO] The stream to add
    def add_stream(stream)
      @streams << stream unless @streams.include?(stream)
    end

    # @param stream [IO] The stream to remove
    def remove_stream(stream)
      @streams.delete(stream)
    end
  end # class IoMultiplexer
end # module Cosmos
