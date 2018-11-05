# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server_config'

module Cosmos
  # Manages starting and stopping all the background tasks which
  # were discovered when parsing the configuration file.
  class BackgroundTasks
    # @param cmd_tlm_server_config [CmdTlmServerConfig] The command telemetry
    #   server configuration
    def initialize(cmd_tlm_server_config)
      @config = cmd_tlm_server_config
      @threads = []
    end

    # Start all background tasks by creating a new Ruby thread for each and then
    # calling their 'call' method once. Tasks which have stopped set to true
    # are not started and must be started by calling #start.
    def start_all
      (0...all.length).each do |index|
        start(index) unless @config.background_tasks[index].stopped
      end
    end

    # Start an individual background task by creating a new Ruby thread and then
    # calling the 'call' method once.
    # @param index [Integer] Which background task to start
    def start(index)
      raise "No task at index #{index}. There are #{@config.background_tasks.length} total tasks." unless index < @config.background_tasks.length
      return if @threads[index] # Don't re-create a running thread. They must call stop first.
      @threads[index] = Thread.new do
        @config.background_tasks[index].thread = Thread.current
        begin
          @config.background_tasks[index].call
        rescue Exception => err
          Logger.error "Background Task '#{@config.background_tasks[index].name}' unexpectedly died"
          Cosmos.handle_fatal_exception(err)
        ensure
          @threads[index] = nil # Remove thread reference
        end
      end
    end

    # Stop all background tasks by calling their stop method and then killing
    # their Ruby thread.
    def stop_all
      (0...all.length).each { |index| stop(index) }
      @threads = []
    end

    # Stop background task by calling their stop method and then killing their
    # Ruby thread.
    # @param index [Integer] Which background task to stop
    def stop(index)
      raise "No task at index #{index}. There are #{@config.background_tasks.length} total tasks." unless index < @config.background_tasks.length
      begin
        @config.background_tasks[index].stop
      rescue
        # Ignore any errors because we're about to kill the thread anyway
      end
      Cosmos.kill_thread(self, @threads[index])
      @threads[index] = nil
    end

    # Return the array of background tasks
    def all
      @config.background_tasks
    end

    def graceful_kill
      # This method is just here to remove warnings - background_task.stop should kill the thread
    end
  end
end
