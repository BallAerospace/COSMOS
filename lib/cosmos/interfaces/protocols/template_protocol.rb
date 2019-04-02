# encoding: ascii-8bit

# Copyright 2017 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/config/config_parser'
require 'cosmos/interfaces/protocols/terminated_protocol'
require 'thread' # For Queue
require 'timeout' # For Timeout::Error

module Cosmos
  # Protocol which delineates packets using delimiter characters. Designed for
  # text based protocols which expect a command and send a response. The
  # protocol handles sending the command and capturing the response.
  class TemplateProtocol < TerminatedProtocol
    # @param write_termination_characters (see TerminatedProtocol#initialize)
    # @param read_termination_characters (see TerminatedProtocol#initialize)
    # @param ignore_lines [Integer] Number of newline terminated reads to
    #   ignore when processing the response
    # @param initial_read_delay [Integer] Initial delay when connecting before
    #   trying to read
    # @param response_lines [Integer] Number of newline terminated lines which
    #   comprise the response
    # @param strip_read_termination (see TerminatedProtocol#initialize)
    # @param discard_leading_bytes (see TerminatedProtocol#initialize)
    # @param sync_pattern (see TerminatedProtocol#initialize)
    # @param fill_fields (see TerminatedProtocol#initialize)
    # @param response_timeout [Float] Number of seconds to wait before timing out
    #   when waiting for a response
    # @param response_polling_period [Float] Number of seconds to wait between polling
    #   for a response
    # @param raise_exceptions [String] Whether to raise exceptions when errors
    #   occur in the protocol like unexpected responses or response timeouts.
    # @param allow_empty_data [true/false/nil] See Protocol#initialize
    def initialize(
      write_termination_characters,
      read_termination_characters,
      ignore_lines = 0,
      initial_read_delay = nil,
      response_lines = 1,
      strip_read_termination = true,
      discard_leading_bytes = 0,
      sync_pattern = nil,
      fill_fields = false,
      response_timeout = 5.0,
      response_polling_period = 0.02,
      raise_exceptions = false,
      allow_empty_data = nil
    )
      super(
        write_termination_characters,
        read_termination_characters,
        strip_read_termination,
        discard_leading_bytes,
        sync_pattern,
        fill_fields,
        allow_empty_data)
      @response_template = nil
      @response_packet = nil
      @response_target_name = nil
      @response_packets = []
      @write_block_queue = Queue.new
      @ignore_lines = ignore_lines.to_i
      @response_lines = response_lines.to_i
      @initial_read_delay = ConfigParser.handle_nil(initial_read_delay)
      @initial_read_delay = @initial_read_delay.to_f if @initial_read_delay
      @response_timeout = ConfigParser.handle_nil(response_timeout)
      @response_timeout = @response_timeout.to_f if @response_timeout
      @response_polling_period = response_polling_period.to_f
      @connect_complete_time = nil
      @raise_exceptions = ConfigParser.handle_true_false(raise_exceptions)
    end

    def reset
      super()
      @initial_read_delay_needed = true
    end

    def connect_reset
      super()
      begin
        @write_block_queue.pop(true) while @write_block_queue.length > 0
      rescue
      end

      @connect_complete_time = Time.now + @initial_read_delay if @initial_read_delay
    end

    def disconnect_reset
      super()
      @write_block_queue << nil # Unblock the write block queue
    end

    def read_data(data)
      return super(data) if (data.length <= 0)

      # Drop all data until the initial_read_delay is complete.
      # This gets rid of unused welcome messages,
      # prompts, and other junk on initial connections
      if @initial_read_delay and @initial_read_delay_needed and @connect_complete_time
        return :STOP if Time.now < @connect_complete_time
        @initial_read_delay_needed = false
      end
      super(data)
    end

    def read_packet(packet)
      if @response_template && @response_packet
        # If lines make it this far they are part of a response
        @response_packets << packet
        return :STOP if @response_packets.length < (@ignore_lines + @response_lines)

        @ignore_lines.times do
          @response_packets.shift
        end
        response_string = ''
        @response_lines.times do
          response = @response_packets.shift
          response_string << response.buffer
        end

        # Grab the response packet specified in the command
        result_packet = System.telemetry.packet(@response_target_name, @response_packet).clone
        result_packet.received_time = nil
        result_packet.id_items.each do |item|
          result_packet.write_item(item, item.id_value, :RAW)
        end

        # Convert the response template into a Regexp
        response_item_names = []
        response_template = @response_template.clone
        response_template_items = @response_template.scan(/<.*?>/)

        response_template_items.each do |item|
          response_item_names << item[1..-2]
          response_template.gsub!(item, "(.*)")
        end
        response_regexp = Regexp.new(response_template)

        # Scan the response for the variables in brackets <VARIABLE>
        # Write the packet value with each of the values received
        response_values = response_string.scan(response_regexp)[0]
        if !response_values || (response_values.length != response_item_names.length)
          handle_error("#{@interface.name}: Unexpected response: #{response_string}")
        else
          response_values.each_with_index do |value, i|
            begin
              result_packet.write(response_item_names[i], value)
            rescue => error
              handle_error("#{@interface.name}: Could not write value #{value} due to #{error.message}")
              break
            end
          end
        end

        @response_packets.clear

        # Release the write
        if @response_template && @response_packet
          @write_block_queue << nil
        end

        return result_packet
      else
        return packet
      end
    end

    def write_packet(packet)
      # Make sure we are past the initial data dropping period
      if @initial_read_delay and @initial_read_delay_needed and @connect_complete_time and Time.now < @connect_complete_time
        delay_needed = @connect_complete_time - Time.now
        sleep(delay_needed) if delay_needed > 0
      end

      # First grab the response template and response packet (if there is one)
      begin
        @response_template = packet.read("RSP_TEMPLATE").strip
        @response_packet = packet.read("RSP_PACKET").strip
        @response_target_name = packet.target_name
        # If the template or packet are empty set them to nil. This allows for
        # the user to remove the RSP_TEMPLATE and RSP_PACKET values and avoid
        # any response timeouts
        if @response_template.empty? || @response_packet.empty?
          @response_template = nil
          @response_packet = nil
          @response_target_name = nil
        end
      rescue
        # If there is no response template we set to nil
        @response_template = nil
        @response_packet = nil
        @response_target_name = nil
      end

      # Grab the command template because that is all we eventually send
      @template = packet.read("CMD_TEMPLATE")
      # Create a new packet to populate with the template
      raw_packet = Packet.new(nil, nil)
      raw_packet.buffer = @template
      raw_packet = super(raw_packet)
      return raw_packet if Symbol === raw_packet

      data = raw_packet.buffer(false)
      # Scan the template for variables in brackets <VARIABLE>
      # Read these values from the packet and substitute them in the template
      # and in the @response_packet name
      @template.scan(/<(.*?)>/).each do |variable|
        value = packet.read(variable[0], :RAW).to_s
        data.gsub!("<#{variable[0]}>", value)
        @response_packet.gsub!("<#{variable[0]}>", value) if @response_packet
      end

      return raw_packet
    end

    def post_write_interface(packet, data)
      if @response_template && @response_packet
        if @response_timeout
          response_timeout_time = Time.now + @response_timeout
        else
          response_timeout_time = nil
        end

        # Block the write until the response is received
        begin
          @write_block_queue.pop(true)
        rescue
          sleep(@response_polling_period)
          retry if !response_timeout_time
          retry if response_timeout_time and Time.now < response_timeout_time
          handle_error("#{@interface.name}: Timeout waiting for response")
        end

        @response_template = nil
        @response_packet = nil
        @response_target_name = nil
        @response_packets.clear
      end
      return super(packet, data)
    end

    def handle_error(msg)
      Logger.error(msg)
      raise msg if @raise_exceptions
    end
  end
end
