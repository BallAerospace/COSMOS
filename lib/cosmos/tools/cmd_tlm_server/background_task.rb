# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
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

    attr_accessor :name
    attr_accessor :thread
    attr_accessor :status

    # Constructor
    def initialize
      @name = nil
      @thread = nil
      @status = nil
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

  end # class BackgroundTask

end
