# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
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

    # Start background tasks by creating a new Ruby thread for each and then
    # calling their 'call' method once.
    def start
      @config.background_tasks.each do |background_task|
        new_thread = Thread.new do
          background_task.thread = Thread.current
          begin
            background_task.call
          rescue Exception => err
            Logger.error "Background Task thread unexpectedly died"
            Cosmos.handle_fatal_exception(err)
          end
        end
        @threads << new_thread
      end
    end

    # Stop background tasks by calling their stop method and then killing their
    # Ruby threads.
    def stop
      @config.background_tasks.each do |background_task|
        begin
          background_task.stop
        rescue
          # Ignore any errors because we're about to kill the thread anyway
        end
      end
      @threads.each {|thread| thread.kill}
      @threads = []
    end

    # Return the array of background tasks
    def all
      @config.background_tasks
    end

  end # class BackgroundTasks

end # module Cosmos
