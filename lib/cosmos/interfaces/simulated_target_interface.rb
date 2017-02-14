# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/interfaces/interface'

module Cosmos
  # An interface class that provides simulated telemetry and command responses
  class SimulatedTargetInterface < Interface

    # @param sim_target_file [String] Filename of the simulator target class
    def initialize(sim_target_file)
      super()

      @connected = false
      @initialized = false
      @count_100hz = 0
      @next_tick_time = nil
      @pending_packets = []

      @sim_target_file = sim_target_file
      @sim_target_class = nil
      @sim_target = nil
      @write_raw_allowed = false
      @raw_logger_pair = nil
    end

    # Initialize the simulated target object and "connect" to the target
    def connect
      unless @initialized
        # Save the current time + 10 ms as the next expected tick time
        @next_tick_time = Time.now + 0.01

        begin
          @sim_target_class = Cosmos.require_class @sim_target_file
        rescue LoadError
          begin
            class_name = "Cosmos::#{@target_names[0]}::#{@sim_target_file.filename_to_class_name}"
            @sim_target_class = class_name.to_class
          rescue NameError => error
            raise $!, "#{class_name} could not be found. Did you REQUIRE #{@sim_target_file} in target.txt?", $!.backtrace
          end
        end
        # Create Simulated Target Object
        @sim_target = @sim_target_class.new(@target_names[0])
        @sim_target.set_rates
        @initialized = true
      end
      @connected = true
    end

    # @return [Boolean] Whether the simulated target is connected (initialized)
    def connected?
      @connected
    end

    # @return [Packet] Returns a simulated target packet from the simulator
    def read
      if @connected
        packet = first_pending_packet()
        return packet if packet

        while true
          # Calculate time to sleep to make ticks 10ms apart
          now = Time.now
          delta = @next_tick_time - now
          if delta > 0.0
            sleep(delta) # Sleep up to 10 ms
            return nil unless @connected
          elsif delta < -1.0
            # Fell way behind - jump next tick time
            @next_tick_time = Time.now
          end

          @pending_packets = @sim_target.read(@count_100hz, @next_tick_time)
          @next_tick_time += 0.01
          @count_100hz += 1

          packet = first_pending_packet()
          return packet if packet
        end
      else
        raise "Interface not connected"
      end
    end

    # @param packet [Packet] Command packet to send to the simulator
    def write(packet)
      if @connected
        # Update count of commands sent through this interface
        @write_count += 1
        @bytes_written += packet.buffer.length

        # Have simulated target handle the packet
        @sim_target.write(packet)
      else
        raise "Interface not connected"
      end
    end

    # write_raw is not implemented and will raise a RuntimeError
    def write_raw(data)
      raise "write_raw not implemented for SimulatedTargetInterface"
    end

    # Raise an error because raw logging is not supported for this interface
    def raw_logger_pair=(raw_logger_pair)
      raise "Raw logging not supported for SimulatedTargetInterface"
    end

    # Disconnect from the simulator
    def disconnect
      @connected = false
    end

    protected

    def first_pending_packet
      packet = nil
      unless @pending_packets.empty?
        @read_count += 1
        packet = @pending_packets.pop.clone
        @bytes_read += packet.buffer.length
      end
      packet
    end
  end
end
