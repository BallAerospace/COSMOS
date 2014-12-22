# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/core_ext/class'
require 'cosmos/core_ext/time'
require 'thread'
require 'logger'

module Cosmos

  # Supports different levels of logging and only writes to stdout if the level
  # is exceeded.
  class Logger

    # @return [Integer] The logging level
    instance_attr_accessor :level
    instance_attr_accessor :detail_string

    @@instance = nil

    # DEBUG only prints DEBUG messages
    DEBUG = ::Logger::DEBUG
    # INFO prints INFO, DEBUG messages
    INFO  = ::Logger::INFO
    # WARN prints WARN, INFO, DEBUG messages
    WARN  = ::Logger::WARN
    # ERROR prints ERROR, WARN, INFO, DEBUG messages
    ERROR = ::Logger::ERROR
    # FATAL prints FATAL, ERROR, WARN, INFO, DEBUG messages
    FATAL = ::Logger::FATAL
    # UNKNOWN always prints
    UNKNOWN = ::Logger::UNKNOWN

    DEBUG_SEVERITY_STRING = ' DEBUG:'
    INFO_SEVERITY_STRING = ' INFO:'
    WARN_SEVERITY_STRING = ' WARN:'
    ERROR_SEVERITY_STRING = ' ERROR:'
    FATAL_SEVERITY_STRING = ' FATAL:'
    UNKNOWN_SEVERITY_STRING = ''

    # @param level [Integer] The initial logging level
    def initialize(level = Logger::UNKNOWN)
      @level = level
      @detail_string = nil
      @mutex = Mutex.new
    end

    # @param message [String] The message to print if the log level is at or
    #   below the method name log level.
    # @param block [Proc] Block to call which should return a string to append
    #   to the log message
    def debug(message = nil, &block)
      log_message(DEBUG_SEVERITY_STRING, message, &block) if @level <= DEBUG
    end

    # (see #debug)
    def info(message = nil, &block)
      log_message(INFO_SEVERITY_STRING, message, &block) if @level <= INFO
    end

    # (see #debug)
    def warn(message = nil, &block)
      log_message(WARN_SEVERITY_STRING, message, &block) if @level <= WARN
    end

    # (see #debug)
    def error(message = nil, &block)
      log_message(ERROR_SEVERITY_STRING, message, &block) if @level <= ERROR
    end

    # (see #debug)
    def fatal(message = nil, &block)
      log_message(FATAL_SEVERITY_STRING, message, &block) if @level <= FATAL
    end

    # (see #debug)
    def unknown(message = nil, &block)
      log_message(UNKNOWN_SEVERITY_STRING, message, &block) if @level <= UNKNOWN
    end

    # (see #debug)
    def self.debug(message = nil, &block)
      self.instance.debug(message, &block)
    end

    # (see #debug)
    def self.info(message = nil, &block)
      self.instance.info(message, &block)
    end

    # (see #debug)
    def self.warn(message = nil, &block)
      self.instance.warn(message, &block)
    end

    # (see #debug)
    def self.error(message = nil, &block)
      self.instance.error(message, &block)
    end

    # (see #debug)
    def self.fatal(message = nil, &block)
      self.instance.fatal(message, &block)
    end

    # (see #debug)
    def self.unknown(message = nil, &block)
      self.instance.unknown(message, &block)
    end

    # @return [Logger] The logger instance
    def self.instance
      @@instance ||= self.new
    end

    protected

    def log_message(severity_string, message, &block)
      @mutex.synchronize do
        if block_given?
          puts "#{Time.now.formatted} #{@detail_string ? "(#{@detail_string}):" : ''}#{severity_string} " << yield
        else
          puts "#{Time.now.formatted} #{@detail_string ? "(#{@detail_string}):" : ''}#{severity_string} #{message}"
        end
      end
    end

  end # class Logger

end
