# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

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
          result = stream.send(method_name, *args)
          result = self if result == stream
          first = false
        else
          stream.send(method_name, *args)
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
