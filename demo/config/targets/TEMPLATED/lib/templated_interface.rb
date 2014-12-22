# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'

module Cosmos

  class TemplatedInterface < TcpipClientInterface
    def initialize(*args)
      super(*args)
      @polling_thread = nil
    end

    def connect
      super()

      # Start a thread to poll telemetry
      Thread.new do |thread|
        @polling_thread.kill if @polling_thread
        @polling_thread = Thread.current
        begin
          while connected?
            cmd("#{@target_names[0]} GET_SETPT_VOLTAGE")
            sleep 1
          end
        rescue Exception => err
          Logger.error "Polling Thread Unexpectedly Died.\n#{err.formatted}"
        end
      end
    end

    def disconnect
      super()
      # Note: This must be after super or the disconnect process will be interrupted by killing
      # the thread
      @polling_thread.kill if @polling_thread
      @polling_thread = nil
    end
  end

end # module Cosmos
