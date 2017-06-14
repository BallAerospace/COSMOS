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

module Cosmos
  # Protocol which delineates packets using delimiter characters. Designed for
  # text based protocols which expect a command and send a response. The
  # protocol handles sending the command and capturing the response.
  module TemplateStreamProtocol
    include TerminatedStreamProtocol

    # Set procotol specific options
    # @param procotol [String] Name of the procotol
    # @param params [Array<Object>] Array of parameter values
    def configure_protocol(protocol, params)
      super(protocol, params)
      configure_stream_protocol(*params) if protocol == 'TemplateStreamProtocol'
    end

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
    def configure_stream_protocol(
      write_termination_characters,
      read_termination_characters,
      ignore_lines = 0,
      initial_read_delay = nil,
      response_lines = 1,
      strip_read_termination = true,
      discard_leading_bytes = 0,
      sync_pattern = nil,
      fill_fields = false)
      super(write_termination_characters,
            read_termination_characters,
            strip_read_termination,
            discard_leading_bytes,
            sync_pattern,
            fill_fields)
      @response_template = nil
      @response_packet = nil
      @read_queue = Queue.new
      @ignore_lines = ignore_lines.to_i
      @response_lines = response_lines.to_i
      @initial_read_delay = ConfigParser.handle_nil(initial_read_delay)
      @initial_read_delay = @initial_read_delay.to_f if @initial_read_delay
    end

    def connect
      # Empty the read queue
      begin
        @read_queue.pop(true) while @read_queue.length > 0
      rescue
      end

      super

      if @initial_read_delay
        sleep(@initial_read_delay)
        loop do
          break if @stream.read_nonblock.length <= 0
        end
      end
    end

    def disconnect
      super()
      @read_queue << nil # Unblock the read queue in the interface thread
    end

    def read(use_queue = true)
      if use_queue
        return @read_queue.pop
      else
        return super()
      end
    end

    # See StreamProtocol#pre_write_packet
    def pre_write_packet(packet)
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
      raw_packet = super(raw_packet)

      data = raw_packet.buffer(false)
      # Scan the template for variables in brackets <VARIABLE>
      # Read these values from the packet and substitute them in the template
      @template.scan(/<(.*?)>/).each do |variable|
        data.gsub!("<#{variable[0]}>", packet.read(variable[0], :RAW).to_s)
      end
      raw_packet
    end

    def post_write_data(packet, data)
      if @response_template && @response_packet
        @ignore_lines.times do
          read(false)
        end
        response_string = ''
        @response_lines.times do
          response = read(false)
          raise "No response received" unless response
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

        @read_queue << result_packet
      end
    end
  end
end
