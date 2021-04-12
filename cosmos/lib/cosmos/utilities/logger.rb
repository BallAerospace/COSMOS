# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'cosmos/core_ext/class'
require 'cosmos/core_ext/time'
require 'cosmos/utilities/store'
require 'socket'
require 'thread'
require 'logger'
require 'time'

module Cosmos

  # Supports different levels of logging and only writes if the level
  # is exceeded.
  class Logger
    # @return [Boolean] Whether to output the message to stdout
    instance_attr_accessor :stdout

    # @return [Integer] The logging level
    instance_attr_accessor :level

    # @return [String] Additional detail to add to messages
    instance_attr_accessor :detail_string

    # @return [String] Fluent tag
    instance_attr_accessor :tag

    # @return [String] Microservice name
    instance_attr_accessor :microservice_name

    # @return [String] Scope
    instance_attr_accessor :scope

    @@mutex = Mutex.new
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

    DEBUG_SEVERITY_STRING = 'DEBUG'
    INFO_SEVERITY_STRING = 'INFO'
    WARN_SEVERITY_STRING = 'WARN'
    ERROR_SEVERITY_STRING = 'ERROR'
    FATAL_SEVERITY_STRING = 'FATAL'

    # @param level [Integer] The initial logging level
    def initialize(level = Logger::INFO)
      @stdout = true
      @level = level
      @scope = nil
      @detail_string = nil
      @container_name = Socket.gethostname
      @microservice_name = nil
      @metric_tag = @container_name + ".metric"
      @tag = @container_name + ".log"
      @mutex = Mutex.new
      @no_store = ENV['NO_STORE']
    end

    # @param message [String] The message to print if the log level is at or
    #   below the method name log level.
    # @param block [Proc] Block to call which should return a string to append
    #   to the log message
    def debug(message = nil, scope: @scope, &block)
      log_message(DEBUG_SEVERITY_STRING, message, scope: scope, &block) if @level <= DEBUG
    end

    # (see #debug)
    def info(message = nil, scope: @scope, &block)
      log_message(INFO_SEVERITY_STRING, message, scope: scope, &block) if @level <= INFO
    end

    # (see #debug)
    def warn(message = nil, scope: @scope, &block)
      log_message(WARN_SEVERITY_STRING, message, scope: scope, &block) if @level <= WARN
    end

    # (see #debug)
    def error(message = nil, scope: @scope, &block)
      log_message(ERROR_SEVERITY_STRING, message, scope: scope, &block) if @level <= ERROR
    end

    # (see #debug)
    def fatal(message = nil, scope: @scope, &block)
      log_message(FATAL_SEVERITY_STRING, message, scope: scope, &block) if @level <= FATAL
    end

    # @param data [Hash] The hash to print if the log level is at or below the
    #   method name log level.
    # @param block [Proc] Block to call which should return a string to append
    #   to the log message
    def metric(data = {}, scope: @scope, &block)
      log_metric(data, scope: scope, &block) if @level <= INFO
    end

    # (see #debug)
    def self.debug(message = nil, scope: nil, &block)
      if scope
        self.instance.debug(message, scope: scope, &block)
      else
        self.instance.debug(message, &block)
      end
    end

    # (see #debug)
    def self.info(message = nil, scope: nil, &block)
      if scope
        self.instance.info(message, scope: scope, &block)
      else
        self.instance.info(message, &block)
      end
    end

    # (see #debug)
    def self.warn(message = nil, scope: nil, &block)
      if scope
        self.instance.warn(message, scope: scope, &block)
      else
        self.instance.warn(message, &block)
      end
    end

    # (see #debug)
    def self.error(message = nil, scope: nil, &block)
      if scope
        self.instance.error(message, scope: scope, &block)
      else
        self.instance.error(message, &block)
      end
    end

    # (see #debug)
    def self.fatal(message = nil, scope: nil, &block)
      if scope
        self.instance.fatal(message, scope: scope, &block)
      else
        self.instance.fatal(message, &block)
      end
    end

    # (see #metric)
    def self.metric(data = {}, scope: nil, &block)
      if scope
        self.instance.metric(data, scope: scope, &block)
      else
        self.instance.metric(data, &block)
      end
    end

    # @return [Logger] The logger instance
    def self.instance
      return @@instance if @@instance
      @@mutex.synchronize do
        @@instance ||= self.new
      end
      @@instance
    end

    protected
    def log_metric(data, scope:, &block)
      @mutex.synchronize do
        data[:time] = Time.now.to_nsec_from_epoch
        data[:@timestamp] = Time.now.xmlschema(3)
        data[:microservice_name] = @microservice_name if @microservice_name
        data[:detail] = @detail_string if @detail_string
        data[:container_name] = @container_name
        if block_given?
          data = yield
        end
        puts data.to_json if @stdout
        unless @no_store
          if scope
            Store.write_topic("#{scope}__cosmos_log_messages", data)
          else
            Store.write_topic("cosmos_log_messages", data)
          end
        end
      end
    end

    def log_message(severity_string, message, scope:, &block)
      @mutex.synchronize do
        data = { time: Time.now.to_nsec_from_epoch, '@timestamp' => Time.now.xmlschema(3), severity: severity_string }
        data[:microservice_name] = @microservice_name if @microservice_name
        data[:detail] = @detail_string if @detail_string
        if block_given?
          message = yield
        end
        data[:container_name] = @container_name
        data[:log] = message
        puts data.to_json if @stdout
        unless @no_store
          if scope
            Store.write_topic("#{scope}__cosmos_log_messages", data)
          else
            Store.write_topic("cosmos_log_messages", data)
          end
        end
      end
    end
  end
end
