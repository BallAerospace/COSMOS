# encoding: ascii-8bit

# Copyright 2017 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/config/config_parser'
require 'cosmos/interfaces/protocols/stream_protocol'
require 'cosmos/interfaces/protocols/terminated_stream_protocol'
require 'thread' # For Queue
require 'timeout' # For Timeout::Error

module Cosmos
  # Protocol which delineates packets using delimiter characters. Designed for
  # text based protocols which expect a command and send a response. The
  # protocol handles sending the command and capturing the response.
  class TemplateStreamProtocol < TerminatedStreamProtocol
    # @param write_termination_characters (see TerminatedStreamProtocol#initialize)
    # @param read_termination_characters (see TerminatedStreamProtocol#initialize)
    # @param ignore_lines [Integer] Number of newline terminated reads to
    #   ignore when processing the response
    # @param initial_read_delay [Integer] Initial delay when connecting before
    #   trying to read the stream
    # @param response_lines [Integer] Number of newline terminated lines which
    #   comprise the response
    # @param strip_read_termination (see TerminatedStreamProtocol#initialize)
    # @param discard_leading_bytes (see TerminatedStreamProtocol#initialize)
    # @param sync_pattern (see TerminatedStreamProtocol#initialize)
    # @param fill_fields (see TerminatedStreamProtocol#initialize)
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
      response_polling_period = 0.02
    )
      super(
        write_termination_characters,
        read_termination_characters,
        strip_read_termination,
        discard_leading_bytes,
        sync_pattern,
        fill_fields)
      @response_template = nil
      @response_packet = nil
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
    end

    def reset
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
      # Drop all data until the initial_read_delay is complete.   This gets rid of unused welcome messages,
      # prompts, and other junk on initial connections
      if @initial_read_delay and @initial_read_delay_needed and @connect_complete_time
        return nil, :STOP if Time.now < @connect_complete_time
        @initial_read_delay_needed = false
      end
      super(data)
    end

    def read_packet(packet)
      # If lines make it this far they are part of a response
      @response_packets << packet
      return nil, :STOP if @response_packets.length < (@ignore_lines + @response_lines)

      @ignore_lines.times do
        @response_packets.pop
      end
      response_string = ''
      @response_lines.times do
        response = @response_packets.pop
        response_string << response.buffer
      end

      # Grab the response packet specified in the command
      result_packet = System.telemetry.packet(@target_names[0], @response_packet).clone
      result_packet.received_time = nil

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
      raise "Unexpected response received: #{response_string}" if !response_values or (response_values.length != response_item_names.length)
      response_values.each_with_index do |value, i|
        result_packet.write(response_item_names[i], value)
      end

      @response_packets.clear
      return result_packet, nil
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
      rescue
        # If there is no response template we set to nil
        @response_template = nil
        @response_packet = nil
      end

      # Grab the command template because that is all we eventually send
      @template = packet.read("CMD_TEMPLATE")
      # Create a new packet to populate with the template
      raw_packet = Packet.new(nil, nil)
      raw_packet.buffer = @template
      raw_packet, control = super(raw_packet)
      return nil, control if control

      data = raw_packet.buffer(false)
      # Scan the template for variables in brackets <VARIABLE>
      # Read these values from the packet and substitute them in the template
      @template.scan(/<(.*?)>/).each do |variable|
        data.gsub!("<#{variable[0]}>", packet.read(variable[0], :RAW).to_s)
      end

      return raw_packet, nil
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
          result = @write_block_queue.pop(true)
        rescue
          sleep(@response_polling_period)
          retry if !response_timeout_time
          retry if response_timeout_time and Time.now < response_timeout_time
          raise Timeout::Error, "Timeout waiting for response"
        end

        @response_template = nil
        @response_packet = nil
        @response_packets.clear
      end
      return super(packet, data)
    end
  end
end
