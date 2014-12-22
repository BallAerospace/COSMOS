# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/io/raw_logger'

module Cosmos

  # Holds a read/write pair of raw loggers
  class RawLoggerPair

    # @return [RawLogger] The read logger
    attr_accessor :read_logger
    # @return [RawLogger] The write logger
    attr_accessor :write_logger

    # @param name [String] name to be added to log file names
    # @param params [Array] raw log writer parameters or empty array
    def initialize(name, params = [])
      if params.empty?
        raw_logger_class = RawLogger
      else
        raw_logger_class = Cosmos.require_class(params[0])
      end
      if params[1]
        @read_logger = raw_logger_class.new(name, :READ, *params[1..-1])
        @write_logger = raw_logger_class.new(name, :WRITE, *params[1..-1])
      else
        @read_logger = raw_logger_class.new(name, :READ)
        @write_logger = raw_logger_class.new(name, :WRITE)
      end
    end

    # Change the raw logger name
    # @param name [String] new name
    def name=(name)
      @read_logger.name = name
      @write_logger.name = name
    end

    # Start raw logging
    def start
      @read_logger.start
      @write_logger.start
    end

    # Close any open raw data log files
    def stop
      @read_logger.stop
      @write_logger.stop
    end

    # Clone the raw logger pair
    def clone
      raw_logger_pair = super()
      raw_logger_pair.read_logger = @read_logger.clone
      raw_logger_pair.write_logger = @write_logger.clone
      raw_logger_pair.read_logger.start if @read_logger.logging_enabled
      raw_logger_pair.write_logger.start if @write_logger.logging_enabled
      raw_logger_pair
    end

  end # class PacketLogWriterPair

end # module Cosmos
