# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/cmd_tlm_server/api'

module Cosmos
  # Handles a user supplied thread to run in the background of the
  # Command and Telemetry Server
  class BackgroundTask
    include Api

    # @return [Integer] The number of background tasks created
    @@count = 0

    # @return [String] Name of the background task
    attr_accessor :name
    # @return [Thread] Ruby thread running the task
    attr_accessor :thread
    # @return [String] Status message to display in the CTS
    attr_accessor :status
    # @return [Boolean] Whether the task is initially stopped when the CTS starts
    attr_accessor :stopped

    # Constructor
    def initialize
      @@count += 1
      @name = "Background Task #{@@count}"
      @thread = nil
      @status = ''
      @stopped = false
    end

    # Subclasses should override the call method which is called once by
    # the Command and Telemetry Server. Thus subclasses should add their own
    # loop and sleep statements if they expect to run continuously.
    def call
      raise "call method must be defined by subclass"
    end

    # The Command and Telemetry Server calls the stop method before killing the
    # Thread which is running the background tasks. This method should be
    # overriden by subclasses to do whatever shutdown is necessary.
    def stop
      # Nothing to do by default
    end
  end
end
