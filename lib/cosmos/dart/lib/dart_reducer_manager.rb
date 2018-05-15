# encoding: ascii-8bit

# Copyright 2018 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'dart_reducer_worker_thread'

class DartReducerStatus
  attr_accessor :count
  attr_accessor :error_count
  attr_accessor :message
  attr_accessor :message_time

  def initialize
    @count = 0
    @error_count = 0
    @message = ''
    @message_time = Time.now
  end
end

# Reduce the decommutated data into the database. It creates a number of
# threads to perform the actual data reduction. Then it queries the database
# for all the decommutation tables and determines which need to be reduced
# by minute, hour, and day.
class DartReducerManager
  include DartCommon

  # Create worker threads to perform the data reduction
  #
  # @param num_threads [Integer] The number of worker threads to create
  def initialize(num_threads = 5)
    message = "Dart Reducer Starting with #{num_threads} threads..."
    Cosmos::Logger.info(message)
    @master_queue = Queue.new
    @locked_tables = []
    @mutex = Mutex.new
    @threads = []
    @status = DartReducerStatus.new
    num_threads.times do |index|
      @threads << DartReducerWorkerThread.new(@master_queue, @locked_tables, @mutex, index + 1, @status)
    end
  end

  # Shutdown each of the worker threads
  def shutdown
    @threads.each {|thread| thread.shutdown}
    @threads.each {|thread| thread.join}
  end

  # Search through all the tables in the database looking for decommutation tables
  # and reduction tables. Then push all found tables onto one of the worker
  # thread queues for processing.
  def run
    begin
      while true
        time_start = Time.now
        # Find base tables that need to be reduced
        base_tables = []
        each_decom_and_reduced_table() do |packet_config_id, table_index, decom_model, minute_model, hour_model, day_model|
          queue_worker(:MINUTE, packet_config_id, table_index, decom_model, minute_model)
          queue_worker(:HOUR, packet_config_id, table_index, minute_model, hour_model)
          queue_worker(:DAY, packet_config_id, table_index, hour_model, day_model)
        end

        # Update status
        status = Status.first
        if (Time.now - @status.message_time) <= 60.0
          status.reduction_message = @status.message
          status.reduction_message_time = @status.message_time
          status.save!
        end
        if @status.count > 0 or @status.error_count > 0
          Status.update_counters(status.id, :reduction_count => @status.count, :reduction_error_count => @status.error_count)
          @status.count = 0
          @status.error_count = 0
        end

        # Throttle to no faster than once every 60 seconds
        delta = Time.now - time_start
        if delta < 60 and delta > 0
          sleep(60 - delta)
        end
      end
    rescue Interrupt
      message = "Dart Reducer Shutting Down..."
      Cosmos::Logger.info(message)
      shutdown()
      exit(0)
    end
  end

  protected

  # Add a task to a worker thread queue
  #
  # @param type [Symbol] One of :MINUTE, :HOUR, :DAY
  # @param packet_config_id [Integer] PacketConfig ID from the database
  # @param table_index [Integer] Table index used in table names
  # @param base_model [ActiveRecord] Database model of the table to be reduced
  # @param reduction_model [ActiveRecord] Database model of the reduction table
  def queue_worker(type, packet_config_id, table_index, base_model, reduction_model)
    thread_queue = @master_queue.pop
    unless @locked_tables.include?([type, packet_config_id, table_index])
      @mutex.synchronize do
        @locked_tables << ([type, packet_config_id, table_index])
      end
      thread_queue << [type, packet_config_id, table_index, base_model, reduction_model]
    end
  end
end
