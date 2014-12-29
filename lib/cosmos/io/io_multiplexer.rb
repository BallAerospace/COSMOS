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

    # @param args [Array<String>] Argument to send to the print method of each
    #   stream
    def print(*args)
      @streams.each {|stream| stream.print(*args)}
      nil
    end

    # @param args [Array<String>] Argument to send to the printf method of each
    #   stream
    def printf(*args)
      @streams.each {|stream| stream.printf(*args)}
      nil
    end

    # @param object [Object] Argument to send to the putc method of each
    #   stream
    def putc(object)
      @streams.each {|stream| stream.putc(object)}
      object
    end

    # @param args [Array<String>] Argument to send to the puts method of each
    #   stream
    def puts(*args)
      @streams.each {|stream| stream.puts(*args)}
      nil
    end

    # Calls flush on each stream
    def flush
      @streams.each {|stream| stream.flush}
    end

    # @param string [String] Argument to send to the write method of each
    #   stream
    # @return [Integer] The length of the string argument
    def write(string)
      @streams.each {|stream| stream.write(string)}
      string.length
    end

    # @param string [String] Argument to send to the write_nonblock method of each
    #   stream
    # @return [Integer] The length of the string argument
    def write_nonblock(string)
      @streams.each {|stream| stream.write_nonblock(string)}
      string.length
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
