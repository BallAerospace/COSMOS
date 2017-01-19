# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/config/config_parser'
require 'thread'

module Cosmos
  # Processes a {Stream} on behalf of an {Interface}. A {Stream} is a
  # primative interface that simply reads and writes raw binary data. The
  # StreamProtocol adds higher level processing including the ability to
  # discard a certain number of bytes from the stream and to sync the stream
  # on a given synchronization pattern. The StreamProtocol operates at the
  # {Packet} abstraction level while the {Stream} operates on raw bytes.
  module StreamProtocol
    ## @return [Integer] The number of bytes read from the stream
    #attr_accessor :bytes_read
    ## @return [Integer] The number of bytes written to the stream
    #attr_accessor :bytes_written
    ## @return [Interface] The interface associated with this
    ##   StreamProtocol.
    #attr_reader :interface
    ## @return [Stream] The stream this StreamProtocol is processing data from
    #attr_reader :stream

    # @param discard_leading_bytes [Integer] The number of bytes to discard
    #   from the binary data after reading from the {Stream}. Note that this is often
    #   used to remove a sync pattern from the final packet data.
    # @param sync_pattern [String] String representing a hex number ("0x1234")
    #   that will be searched for in the raw {Stream}. Bytes encountered before
    #   this pattern is found are discarded.
    # @param fill_fields [Boolean] Fill any required fields when writing packets
    def configure_stream_protocol(discard_leading_bytes = 0, sync_pattern = nil, fill_fields = false)
      @discard_leading_bytes = discard_leading_bytes.to_i
      @sync_pattern = ConfigParser.handle_nil(sync_pattern)
      @sync_pattern = @sync_pattern.hex_to_byte_string if @sync_pattern
      @fill_fields = ConfigParser.handle_true_false(fill_fields)
      @data = ''
    end

    # Clears the data attribute and sets the data encoding
    def connect
      super()
      @data = ''
      @data.force_encoding('ASCII-8BIT')
    end

    # Clears the data attribute
    def disconnect
      super()
      @data = ''
    end

    # Reads from the stream. It can look for a sync pattern before
    # creating a Packet. It can discard a set number of bytes at the beginning
    # of the stream before creating the Packet.
    #
    # @return [Packet|nil] A Packet of consisting of the bytes read from the
    #   stream.
    def read_data
      # Loop until we have a packet to give
      loop do
        result = handle_sync_pattern()
        return nil unless result

        # Reduce the data to a single packet
        packet_data = reduce_to_single_packet()
        return nil unless packet_data

        # Discard leading bytes if necessary
        packet_data.replace(packet_data[@discard_leading_bytes..-1]) if @discard_leading_bytes > 0

        # Return data based on final_receive_processing
        if packet_data
          if packet_data.length > 0
            return packet_data
          else
            # Packet should be ignored
            next
          end
        else
          # Connection lost
          return nil
        end
      end # loop do
    end

    # Writes the packet data to the stream.
    #
    # @param data [String] Packet data to write to the stream
    # @return [String] The original raw packet data
    def write_data(data)
      @stream.write(data)
      data
    end

    # Called to perform modifications on a command packet before it is sent
    #
    # @param packet [Packet] Original packet
    # @return [Packet] Potentially modified packet
    def pre_write_packet(packet)
      packet = super(packet)
      # If we're filling the sync pattern and the sync pattern is part of the
      # packet (since we're not discarding any leading bytes) then we have to
      # fill the sync pattern in the actual packet so do it here.
      if @fill_fields && @sync_pattern && @discard_leading_bytes == 0
        # Directly write the packet buffer and fill in the sync pattern
        BinaryAccessor.write(@sync_pattern, 0, @sync_pattern.length * 8, :BLOCK,
                             packet.buffer(false), :BIG_ENDIAN, :ERROR)
      end
      packet
    end

    # Called to perform modifications on write data before sending it to the stream
    #
    # @param packet_data [String] Raw packet data
    # @return [String] Potentially modified packet data
    def pre_write_data(data)
      data = super(data)
      # If we're filling the sync pattern and discarding the leading bytes
      # during a read then we need to put them back during a write.
      # If we're discarding the bytes then by definition they can't be part
      # of the packet so we just modify the data.
      if @fill_fields && @sync_pattern && @discard_leading_bytes > 0
        data = ("\x00" * @discard_leading_bytes) << data
        BinaryAccessor.write(@sync_pattern, 0, @sync_pattern.length * 8, :BLOCK,
                             data, :BIG_ENDIAN, :ERROR)
      end
      data
    end

    protected

    # @return [Boolean] Whether we successfully found a sync pattern
    def handle_sync_pattern
      if @sync_pattern
        loop do
          # Make sure we have some data to look for a sync word in
          read_minimum_size(@sync_pattern.length)
          return false if @data.length <= 0
          # Find the beginning of the sync pattern
          sync_index = @data.index(@sync_pattern.getbyte(0).chr)
          if sync_index
            # Make sure we have enough data for the whole sync pattern past this index
            read_minimum_size(sync_index + @sync_pattern.length)
            return false if @data.length <= 0

            # Check for the rest of the sync pattern
            found = true
            index = sync_index
            @sync_pattern.each_byte do |byte|
              if @data.getbyte(index) != byte
                found = false
                break
              end
              index += 1
            end

            if found
              if sync_index != 0
                discard_length = @data[0..(sync_index - 1)].length
                log_discard(discard_length, true)
                # Delete Data Before Sync Pattern
                @data.replace(@data[sync_index..-1])
              end
              return true

            else # not found
              log_discard(@data[0..sync_index].length, false)
              # Delete Data Before and including first character of suspected sync Pattern
              @data.replace(@data[(sync_index + 1)..-1])
              next
            end # if found

          else # sync_index = nil
            log_discard(@data.length, false)
            @data.replace('')
            next
          end # unless sync_index.nil?
        end # end loop
      end # if @sync_pattern

      true
    end

    def log_discard(length, found)
      Logger.error("Sync #{'not ' unless found}found. Discarding #{length} bytes of data.")
      if @data.length >= 6
        Logger.error(sprintf("Starting: 0x%02X 0x%02X 0x%02X 0x%02X 0x%02X 0x%02X\n",
          @data.getbyte(0), @data.getbyte(1), @data.getbyte(2), @data.getbyte(3), @data.getbyte(4), @data.getbyte(5)))
      end
    end

    def reduce_to_single_packet
      if @data.length <= 0
        # Need to get some data
        read_and_handle_timeout()
        return nil if @data.length <= 0
      end

      # Reduce to packet data and clear data for next packet
      packet_data = @data.clone
      @data.replace('')

      packet_data
    end

    def read_and_handle_timeout
      begin
        data = @stream.read
        @bytes_read += data.length
      rescue Timeout::Error
        Logger.instance.error "Timeout waiting for data to be read"
        data = ''
      end
      # data.length == 0 means that the stream was closed.  Need to clear out @data and be done.
      if data.length == 0
        @data.replace('')
        return
      end
      @data << data
    end

    def read_minimum_size(required_num_bytes)
      while (@data.length < required_num_bytes)
        read_and_handle_timeout()
        return if @data.length <= 0
      end
    end
  end
end
