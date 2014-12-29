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
      klass = stream_protocol_class.to_class
      unless klass
        begin
          require stream_protocol_class.class_name_to_filename
        # If the stream protocol doesn't exist require will throw a LoadError
        rescue LoadError => err
          msg = "Unable to require " \
            "#{stream_protocol_class.class_name_to_filename} due to #{err.message}. " \
            "Ensure #{stream_protocol_class.class_name_to_filename} "\
            "is in the COSMOS lib directory."
          Logger.instance.error msg
          raise msg
        # If the stream protocol exists but has problems we rescue those here
        rescue => err
          msg = "Unable to require " \
            "#{stream_protocol_class.class_name_to_filename} due to #{err.message}."
          Logger.instance.error msg
          raise msg
        end
      end

      @stream_protocol = klass.new(*stream_protocol_args)
      @stream_protocol.interface = self
    end

    # Connect is left undefined as it must be defined by a subclass.

    # @return [Boolean] Whether the stream protocol is connected to the target
    def connected?
      @stream_protocol.connected?
    end

    # Disconnect the stream protocol from the target
    def disconnect
      @stream_protocol.disconnect
    end

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

    # @return [Integer] The number of bytes read by the stream protocol
    def bytes_read
      @stream_protocol.bytes_read
    end

    # @return [Integer] Sets the number of bytes read by the stream protocol
    def bytes_read=(bytes_read)
      @stream_protocol.bytes_read = bytes_read
    end

    # @return [Integer] The number of bytes written to the stream protocol
    def bytes_written
      @stream_protocol.bytes_written
    end

    # @return [Integer] Sets the number of bytes written to the stream protocol
    def bytes_written=(bytes_written)
      @stream_protocol.bytes_written = bytes_written
    end

    # These methods do not exist in StreamInterface but can be implemented by
    # subclasses and will be called by the {StreamProtocol} when processing
    # the data in the {Stream}.
    #
    # Subclasses of {StreamProtocol} can implement the same method. However,
    # if the callback method is implemented in the interface then the
    # subclass method is not called.
    #
    # Thus if you are implementing an Interface that uses a {StreamProtocol}
    # and choose to implement this method, you must be aware of any
    # processing that the {StreamProtocol} does in the same method
    # and re-implement it (or call @stream_protocol.post_read_data(packet_data), etc) in yours.
    #
    # @!method post_read_data(packet_data)
    # @!method post_read_packet(packet)
    # @!method pre_write_packet(packet)

  end # class StreamInterface

end # module Cosmos
