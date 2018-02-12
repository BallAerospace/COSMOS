# encoding: ascii-8bit

# Copyright 2018 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require File.expand_path('../../config/environment', __FILE__)
require 'dart_common'
require 'dart_decommutator'
require 'dart_logging'

ItemToDecomTableMapping

# Thread which performs data reduction in the DART database.
class DartReducerWorkerThread
  # Create a new thread and start it
  #
  # @param master_queue [Queue] Queue which the new thread will be added to
  # @param locked_tables [Array<Array<Symbol, Integer, Integer>>] Array of
  #   all the tables which are currently being processed. The first parameter
  #   is the table type and must be :MINUTE, :HOUR or :DAY. The second and
  #   third values are the PacketConfig ID and table index.
  # @param mutex [Mutex] Mutex used to synchronize access to the locked_tables
  # @param instance_num [Integer] Simple counter to trace the thread instance
  def initialize(master_queue, locked_tables, mutex, instance_num)
    @instance_num = instance_num
    @running = true
    @master_queue = master_queue
    @locked_tables = locked_tables
    @mutex = mutex
    @thread_queue = Queue.new
    # Start the thread which will wait on @thread_queue.pop
    @thread = Thread.new { work() }
    # Add the local @thread_queue to the @master_queue so jobs can be added
    @master_queue << @thread_queue
  end

  # Pop a job off the queue and find items which are able to be reduced.
  # Calculate the min, max, and average value over the reduction period
  # (min, hour, or day) and save to the reduction table tXXX_YYY_Z where
  # XXX is the PacketConfig ID, YYY is the table index, and Z is 'm', 'h', or 'd'
  # (minute, hour, day).
  def work
    while @running # Set to false in shutdown()
      job_type, packet_config_id, table_index, base_model, reduction_model = @thread_queue.pop
      break unless job_type # shutdown was called

      # Find all the items which are able to be reduced (reduced = true)
      mappings = ItemToDecomTableMapping.where("packet_config_id = ? and table_index = ? and reduced = true",
        packet_config_id, table_index)
      # The only way to not have any mappings is if the packet contains no items
      # which can be reduced (no integer or float values). This would be extremely rare.
      if mappings.length == 0
        Cosmos::Logger.debug("No Mappings for JobType #{job_type}: #{packet_config_id}: #{table_index}")
        complete_job(job_type, packet_config_id, table_index)
        next
      end

      time_delta, base_model_time_column, time_method = job_attributes(job_type)
      rows = []
      # Find all the rows in the decommutation table which are ready to reduce
      base_model.where("reduced_state = #{DartDecommutator::READY_TO_REDUCE}").order("meta_id ASC, #{base_model_time_column} ASC").find_each do |row|
        rows << row
        first_row_time = rows[0].send(base_model_time_column)
        last_row_time = rows[-1].send(base_model_time_column)
        # Ensure we have conditions to process the reduction data
        next unless (last_row_time - first_row_time) > time_delta || # Enough samples or
            # The time attribute (min, hour, day) has changed or
            first_row_time.send(time_method) != last_row_time.send(time_method) ||
            rows[0].meta_id != rows[-1].meta_id # New meta data

        # Sample from the start to the second to last row because the last row
        # is where we detected a change. The last row will be part of a new sample set.
        sample_rows = rows[0..-2]
        new_row = reduction_model.new
        new_row.start_time = first_row_time
        new_row.num_samples = sample_rows.length
        new_row.meta_id = sample_rows[0].meta_id
        # Process each of the ItemToDecomTableMapping to get the item to be reduced
        mappings.each do |mapping|
          item_name = "i#{mapping.item_index}"
          min_item_name = "i#{mapping.item_index}min"
          max_item_name = "i#{mapping.item_index}max"
          avg_item_name = "i#{mapping.item_index}avg"
          min_value = nil
          max_value = nil
          avg_value = 0.0
          total_samples = 0
          min_nan_found = false
          max_nan_found = false
          avg_nan_found = false
          # Process each of the rows in the base model which is the decommutation table
          # or a lesser reduction table (the minute or hour table).
          sample_rows.each do |row_to_reduce|
            # If we processing minute data we're reading from the base decommutation table
            # thus there is only raw values to read
            if job_type == :MINUTE
              value = row_to_reduce.read_attribute(item_name)
              min_sample = value
              max_sample = value
              avg_sample = value
              if value.nil?
                Cosmos::Logger.error("#{item_name} is nil in #{row_to_reduce.class}:#{row_to_reduce.id}")
                next
              end
            else # :HOUR or :DAY
              # We're processing hour or day data so we're reducing previously reduced data
              # thus there are min, max, and average values to read
              min_sample = row_to_reduce.read_attribute(min_item_name)
              max_sample = row_to_reduce.read_attribute(max_item_name)
              avg_sample = row_to_reduce.read_attribute(avg_item_name)
              if min_sample.nil?
                Cosmos::Logger.error("#{min_item_name} is nil in #{row_to_reduce.class}:#{row_to_reduce.id}")
                next
              end
              if max_sample.nil?
                Cosmos::Logger.error("#{max_item_name} is nil in #{row_to_reduce.class}:#{row_to_reduce.id}")
                next
              end
              if avg_sample.nil?
                Cosmos::Logger.error("#{avg_item_name} is nil in #{row_to_reduce.class}:#{row_to_reduce.id}")
                next
              end
            end

            if nan_value?(min_sample)
              min_nan_found = true
            else
              if !min_value or min_sample < min_value
                min_value = min_sample
              end
            end

            if nan_value?(max_sample)
              max_nan_found = true
            else
              if !max_value or max_sample > max_value
                max_value = max_sample
              end
            end

            if nan_value?(avg_sample)
              avg_nan_found = true
            else
              # MINUTE data is reducing the decommutated values
              if job_type == :MINUTE
                avg_value += avg_sample
                total_samples += 1
              else # :HOUR or :DAY
                # Weight the average by multiplying by the number of samples
                avg_value += (avg_sample * row_to_reduce.num_samples)
                total_samples += row_to_reduce.num_samples
              end
            end
          end
          avg_value = avg_value / total_samples if total_samples != 0
          min_value = Float::NAN if min_nan_found and !min_value
          max_value = Float::NAN if max_nan_found and !max_value
          avg_value = Float::NAN if avg_nan_found and total_samples == 0
          new_row.write_attribute(min_item_name, min_value)
          new_row.write_attribute(max_item_name, max_value)
          new_row.write_attribute(avg_item_name, avg_value)
        end
        # Need to transaction the new_row.save! and base_model.update_all to ensure DB integrity
        new_row.save! # Create the reduced data row in the database
        # Mark the original rows as reduced!
        base_model.where(id: sample_rows.map(&:id)).update_all(:reduced_state => DartDecommutator::REDUCED)
        rows = rows[-1..-1] # Start a new sample with the last item in the previous sample
        Cosmos::Logger.info("Created #{new_row.class}:#{new_row.id} with #{mappings.length} items from #{new_row.num_samples} samples")
      end
      complete_job(job_type, packet_config_id, table_index)
    end # while @running
    Cosmos::Logger.info("Reducer Thread #{@instance_num} Shutdown")
  rescue Exception => error
    Cosmos::Logger.error("Reducer Thread Unexpectedly Died: #{error.formatted}")
  end

  # Shutdown the worker thread
  def shutdown
    @running = false
    # Push the queue to allow the thread to run and shutdown
    @thread_queue << nil
  end

  # Kill the worker thread
  def join
    Cosmos.kill_thread(self, @thread)
  end

  # Call shutdown to gracefully shutdown the worker thread
  def graceful_kill
    shutdown()
  end

  protected

  # @return [Boolean] Whether the value is Not A Number (nan)
  def nan_value?(value)
    value.is_a?(Float) && (value.nan? || !value.finite?)
  end

  # Remove the job from the @locked_tables and add the worker thread back
  # to the @master_queue so additional jobs can be scheduled
  #
  # @param job_type [Symbol] One of :MINUTE, :HOUR, or :DAY
  # @param packet_config_id [Integer] PacketConfig ID from the database
  # @param table_index [Integer] Table index used in table names
  def complete_job(job_type, packet_config_id, table_index)
    @mutex.synchronize do
      @locked_tables.delete([job_type, packet_config_id, table_index])
    end
    @master_queue << @thread_queue
  end

  # Get various attributes associated with a job type
  #
  # @param job_type [Symbol] One of :MINUTE, :HOUR, or :DAY
  # @return [Array<Float, String, Symbol>] Array of three items: Float time delta
  #   which is the number of seconds in the time period, String database model time
  #   column name, and Symbol method to call on the resulting Ruby Time object to
  #   get the minute, hour, or day.
  def job_attributes(job_type)
    case job_type
    when :MINUTE
      return 60.0, "time", :min
    when :HOUR
      return 3600.0, "start_time", :hour
    when :DAY
      return 86400.0, "start_time", :yday
    else # Should never get this since we control the jobs so raise
      raise "Reducer Thread Unexpected Job Type: #{job_type}"
    end
  end
end

# Reduce the decommutated data into the database. It creates a number of
# threads to perform the actual data reduction. Then it queries the database
# for all the decommutation tables and determines which need to be reduced
# by minute, hour, and day.
class DartReducer
  include DartCommon

  # Create worker threads to perform the data reduction
  #
  # @param num_threads [Integer] The number of worker threads to create
  def initialize(num_threads = 5)
    Cosmos::Logger.info("Dart Reducer Starting with #{num_threads} threads...")
    @master_queue = Queue.new
    @locked_tables = []
    @mutex = Mutex.new
    @threads = []
    num_threads.times do |index|
      @threads << DartReducerWorkerThread.new(@master_queue, @locked_tables, @mutex, index + 1)
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
  def start
    begin
      while true
        time_start = Time.now
        # Find base tables that need to be reduced
        base_tables = []
        ActiveRecord::Base.connection.tables.each do |table|
          # Since the decommutation tables are created dynamically we search
          # through all the tables looking for tables named something like
          # tXXX_YYY where XXX is the PacketConfig ID and YYY is the table index
          if table.to_s =~ /^t(\d+)_(\d+)$/ # ASCII art? No! Regex!
            packet_config_id = $1.to_i
            table_index = $2.to_i
            # Get the base decommutation table model
            decom_model = get_table_model(table)
            # Find the reduction table models
            minute_model = get_table_model(table, "_m")
            hour_model = get_table_model(table, "_h")
            day_model = get_table_model(table, "_d")
            # Queue up the worker threads with the reduction jobs
            queue_worker(:MINUTE, packet_config_id, table_index, decom_model, minute_model)
            queue_worker(:HOUR, packet_config_id, table_index, minute_model, hour_model)
            queue_worker(:DAY, packet_config_id, table_index, hour_model, day_model)
          end
        end
        # Throttle to no faster than once every 60 seconds
        delta = Time.now - time_start
        if delta < 60 and delta > 0
          sleep(60 - delta)
        end
      end
    rescue Interrupt
      Cosmos::Logger.info("Dart Reducer Shutting Down...")
      shutdown()
      exit(0)
    end
  end

  protected

  # Get the ActiveRecord model for a database table
  #
  # @param table [String] Database table name
  # @param reduction_modifier [String] One of "_m", "_h", "_d"
  # @return [ActiveRecord] Database model for a commutation or reduction table
  #   Commutatiohn tables are named tXXX_YYY where XXX is the PacketConfig ID,
  #   and YYY is the table index. Reduction tables have a _m, _h, _d extension
  #   on the table name.
  def get_table_model(table, reduction_modifier = "")
    model_name = "T" + table[1..-1] + reduction_modifier
    begin
      model = Cosmos.const_get(model_name)
    rescue
      # Need to create model
      model = Class.new(ActiveRecord::Base) do
        self.table_name = table + reduction_modifier
      end
      Cosmos.const_set(model_name, model)
    end
    return model
  end

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

# Start the DartReducer
Cosmos.catch_fatal_exception do
  DartCommon.handle_argv

  Cosmos::Logger.level = Cosmos::Logger::INFO
  dart_logging = DartLogging.new('dart_reducer')
  num_threads = ENV['DART_NUM_REDUCERS']
  num_threads ||= 5
  num_threads = num_threads.to_i
  dr = DartReducer.new(num_threads)
  dr.start
  dart_logging.stop
end
