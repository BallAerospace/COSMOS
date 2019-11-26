# encoding: ascii-8bit

# Copyright 2018 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'dart_common'
require 'dart_logging'
require 'thread'

# Rails Json screws up COSMOS handling of Nan, etc.
require "active_support/core_ext/object/json"
module ActiveSupport
  module ToJsonWithActiveSupportEncoder # :nodoc:
    def to_json(options = nil)
      super(options)
    end
  end
end

# JsonDRb server which responds to queries for decommutated and reduced data
# from the database.
class DartMasterQuery
  include DartCommon

  def initialize(ples_per_request = 5)
    # Keep a thread to make sure we have the current list of items to decom
    @ples_per_request = ples_per_request
    @mutex = Mutex.new
    @decom_list = []
    @thread = Thread.new do
      loop do
        # Get all entries that are ready and decommutation hasn't started
        if @decom_list.length <= 0
          @mutex.synchronize do
            begin
              @decom_list.replace(PacketLogEntry.where("decom_state = #{PacketLogEntry::NOT_STARTED} and ready = true").order("id ASC").limit(1000).pluck(:id))
            rescue Exception => error
              Cosmos::Logger.error("Error getting packets to decom\n#{error.formatted}")
            end
          end
        else
          sleep(1)
        end
      end
    end
  end

  # Returns the id of a ple that needs to be decommed next
  #
  def get_decom_ple_ids()
    begin
      @mutex.synchronize do
        result = []
        @ples_per_request.times do
          ple_id = @decom_list.shift
          result << ple_id if ple_id
        end
        return result
      end
    rescue Exception => error
      msg = "Master Error: #{error.message}"
      raise $!, msg, $!.backtrace
    end
  end

end
