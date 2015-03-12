# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/config/config_parser'
require 'cosmos/streams/stream_protocol'
require 'cosmos/streams/terminated_stream_protocol'
require 'thread' # For Queue

module Cosmos

  class TemplateStreamProtocol < TerminatedStreamProtocol
    def initialize(write_termination_characters,
      read_termination_characters,
      ignore_lines = 0,
      initial_read_delay = nil,
      response_lines = 1,
      strip_read_termination = true,
      discard_leading_bytes = 0,
      sync_pattern = nil,
      fill_sync_pattern = false)
      super(write_termination_characters,
            read_termination_characters,
            strip_read_termination,
            discard_leading_bytes,
            sync_pattern,
            fill_sync_pattern)
      @response_template = nil
      @response_packet = nil
      @read_queue = Queue.new
      @ignore_lines = ignore_lines.to_i
      @response_lines = response_lines.to_i
      @initial_read_delay = ConfigParser.handle_nil(initial_read_delay)
      @initial_read_delay = @initial_read_delay.to_f if @initial_read_delay
    end

    def connect(stream)
      # Empty the read queue
      begin
        @read_queue.pop(true) while @read_queue.length > 0
      rescue
      end

      super(stream)

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
      template = packet.read("CMD_TEMPLATE")
      # Create a new empty packet to call super on
      raw_packet = Packet.new(nil, nil)
      raw_packet.buffer = template
      # Call super to allow the super classes to massage the packet data
      data = super(raw_packet)
      # Scan the template for variables in brackets <VARIABLE>
      # Read these values from the packet and substitute them in the template
      template.scan(/<(.*?)>/).each do |variable|
        data.gsub!("<#{variable[0]}>", packet.read(variable[0], :RAW).to_s)
      end
      data
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
        result_packet = System.telemetry.packet(@interface.target_names[0], @response_packet).clone
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

  end # class TemplateStreamProtocol

end # module Cosmos
