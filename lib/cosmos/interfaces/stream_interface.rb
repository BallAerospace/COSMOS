# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/interfaces/interface'
# Require all the stream protocols. Additional general purpose stream
# protocols should be added to the require list.
require 'cosmos/streams/burst_stream_protocol'
require 'cosmos/streams/fixed_stream_protocol'
require 'cosmos/streams/length_stream_protocol'
require 'cosmos/streams/preidentified_stream_protocol'
require 'cosmos/streams/template_stream_protocol'
require 'cosmos/streams/terminated_stream_protocol'

module Cosmos

  # Stream interfaces use stream protocols to interface with the target. This
  # class simply passes through each method to identically named methods in the
  # stream protocol class. This class is an abstract class and should not be
  # used directly. It should be subclassed and the connect method implemented.
  class StreamInterface < Interface

    # @param stream_protocol_type [String] Combined with 'StreamProtocol'
    #   this should resolve to a COSMOS stream protocol class
    # @param stream_protocol_args [Array] Arguments to pass to the stream
    #   protocol class constructor
    def initialize(stream_protocol_type, *stream_protocol_args)
      super()

      stream_protocol_class = stream_protocol_type.to_s.capitalize << 'StreamProtocol'
      klass = Cosmos.require_class(stream_protocol_class.class_name_to_filename)
      @stream_protocol = klass.new(*stream_protocol_args)
      @stream_protocol.interface = self

      # Build methods to simply defer to the underlying stream_protocol
      %i(connected? disconnect bytes_read bytes_written).each do |method|
        define_singleton_method(method) do
          @stream_protocol.send(method)
        end
      end
      # Build methods that take a parameter to simply defer to the underlying stream_protocol
      %i(bytes_read= bytes_written=).each do |method|
        define_singleton_method(method) do |var|
          @stream_protocol.send(method, var)
        end
      end
      # These methods only defer to the stream protocol if it implements them
      %i(post_read_data post_read_packet pre_write_packet pre_write_data).each do |method|
        if @stream_protocol.respond_to?(method)
          define_singleton_method(method) do |var|
            @stream_protocol.send(method, var)
          end
        end
      end
    end

    # Connect is left undefined as it must be defined by a subclass.

    # Read a packet from the stream protocol
    def read
      packet = @stream_protocol.read
      @read_count += 1 if packet
      packet
    end

    # Write a packet to the stream protocol
    #
    # @param packet [Packet]
    def write(packet)
      if connected?()
        begin
          @stream_protocol.write(packet)
          @write_count += 1
        rescue Exception => err
          Logger.instance.error("Error writing to interface : #{@name}")
          disconnect()
          raise err
        end
      else
        raise "Interface not connected for write : #{@name}"
      end
    end

    # Write a raw binary string to the stream protocol
    #
    # @param data [String] Raw binary string
    def write_raw(data)
      if connected?()
        begin
          @stream_protocol.write_raw(data)
          @write_count += 1
        rescue Exception => err
          Logger.instance.error("Error writing raw data to interface : #{@name}")
          disconnect()
          raise err
        end
      else
        raise "Interface not connected for write_raw : #{@name}"
      end
    end

  end # class StreamInterface

end # module Cosmos
