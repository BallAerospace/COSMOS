require File.expand_path('../../config/environment', __FILE__)
require 'dart_common'
require 'dart_logging'

ItemToDecomTableMapping

class DartReducerWorkerThread

  def initialize(master_queue, locked_tables, mutex, instance_num)
    @instance_num = instance_num
    @running = true
    @master_queue = master_queue
    @locked_tables = locked_tables
    @mutex = mutex
    @thread_queue = Queue.new
    @thread = Thread.new { work() }
    @master_queue << @thread_queue
  end

  def work
    begin
      while(@running)
        begin
          job_type, packet_config_id, table_index, model1, model2 = @thread_queue.pop
          break unless job_type

          mappings = ItemToDecomTableMapping.where("packet_config_id = ? and table_index = ? and reduced = true", packet_config_id, table_index)
          if mappings.length > 0
            # Perform job
            case job_type
            when :MINUTE
              time_delta = 60.0
              model1_time_column = "time"
              time_attribute = :min
            when :HOUR
              time_delta = 3600.0
              model1_time_column = "start_time"
              time_attribute = :hour
            when :DAY
              time_delta = 86400.0
              model1_time_column = "start_time"
              time_attribute = :yday
            else
              Cosmos::Logger.error("Reducer Thread Unexpected Job Type: #{job_type}")
            end

            rows = []
            model1.where("reduced_state = 0").order("meta_id ASC, #{model1_time_column} ASC").find_each do |row|
              rows << row
              if (rows[-1].send(model1_time_column) - rows[0].send(model1_time_column)) > time_delta or rows[0].send(model1_time_column).send(time_attribute) != rows[-1].send(model1_time_column).send(time_attribute) or rows[0].meta_id != rows[-1].meta_id
                sample_rows = rows[0..-2]
                new_row = model2.new
                new_row.start_time = sample_rows[0].send(model1_time_column)
                new_row.num_samples = sample_rows.length
                new_row.meta_id = sample_rows[0].meta_id
                mappings.each do |mapping|
                  item_name = "i#{mapping.item_index}"
                  max_item_name = "i#{mapping.item_index}max"
                  min_item_name = "i#{mapping.item_index}min"
                  avg_item_name = "i#{mapping.item_index}avg"
                  max_value = nil
                  min_value = nil
                  avg_value = 0.0
                  total_samples = 0
                  max_nan_found = false
                  min_nan_found = false
                  avg_nan_found = false
                  sample_rows.each do |row_to_reduce|
                    if job_type == :MINUTE
                      value = row_to_reduce.read_attribute(item_name)
                      max_sample = value
                      min_sample = value
                      avg_sample = value
                      if value.nil?
                        Cosmos::Logger.error("#{item_name} is nil in #{row_to_reduce.class}:#{row_to_reduce.id}")
                        next
                      end                    
                    else
                      max_sample = row_to_reduce.read_attribute(max_item_name)
                      min_sample = row_to_reduce.read_attribute(min_item_name)
                      avg_sample = row_to_reduce.read_attribute(avg_item_name)                  
                      if max_sample.nil?
                        Cosmos::Logger.error("#{max_item_name} is nil in #{row_to_reduce.class}:#{row_to_reduce.id}")
                        next
                      end
                      if min_sample.nil?
                        Cosmos::Logger.error("#{min_item_name} is nil in #{row_to_reduce.class}:#{row_to_reduce.id}")
                        next
                      end
                      if avg_sample.nil?
                        Cosmos::Logger.error("#{avg_item_name} is nil in #{row_to_reduce.class}:#{row_to_reduce.id}")
                        next
                      end
                    end
                    
                    unless (max_sample.is_a?(Float) and (avg_sample.nan? or !avg_sample.finite?))
                      if !max_value or max_sample > max_value 
                        max_value = max_sample 
                      end
                    else
                      max_nan_found = true
                    end 
                      
                    unless (min_sample.is_a?(Float) and (avg_sample.nan? or !avg_sample.finite?))
                      if !min_value or min_sample < min_value 
                        min_value = min_sample 
                      end
                    else
                      min_nan_found = true
                    end 

                    unless (avg_sample.is_a?(Float) and (avg_sample.nan? or !avg_sample.finite?))
                      if job_type == :MINUTE
                        avg_value += avg_sample
                        total_samples += 1
                      else
                        avg_value += (avg_sample * row_to_reduce.num_samples)
                        total_samples += row_to_reduce.num_samples
                      end
                    else
                      avg_nan_found = true
                    end
                  end
                  avg_value = avg_value / total_samples if total_samples != 0
                  max_value = Float::NAN if max_nan_found and !max_value
                  min_value = Float::NAN if min_nan_found and !min_value
                  avg_value = Float::NAN if avg_nan_found and total_samples == 0
                  new_row.write_attribute(max_item_name, max_value)
                  new_row.write_attribute(min_item_name, min_value)
                  new_row.write_attribute(avg_item_name, avg_value)
                end
                # Need to transaction the below as it is possible to create reduced and not update original
                new_row.save!
                Cosmos::Logger.info("Created #{new_row.class}:#{new_row.id} with #{mappings.length} items from #{new_row.num_samples} samples")
                model1.where(id: sample_rows.map(&:id)).update_all(:reduced_state => 2)
                rows = rows[-1..-1]
              end
            end
          else
            Cosmos::Logger.debug("No Mappings for JobType #{job_type}: #{packet_config_id}: #{table_index}")
          end   
        rescue Exception => error
          Cosmos::Logger.error("Reducer Thread Exception: #{error.formatted}")
        end
        Cosmos::Logger.info("Completed JobType #{job_type}: #{packet_config_id}: #{table_index}")

        @mutex.synchronize do
          @locked_tables.delete([job_type, packet_config_id, table_index])
        end
        @master_queue << @thread_queue
      end
    rescue Exception => err
      Cosmos::Logger.error("Reducer Thread Unexpectedly Died: #{err.formatted}")
    end

    Cosmos::Logger.info("Reducer Thread #{@instance_num} Shutdown")
  end

  def shutdown
    @running = false
    @thread_queue << nil
  end

  def join
    Cosmos.kill_thread(self, @thread)
  end

  def graceful_kill
    shutdown()
  end
end

class DartReducer
  include DartCommon

  def initialize(num_threads = 5)
    Cosmos::Logger.info("Dart Reducer Starting with #{num_threads} threads...")
    @master_queue = Queue.new
    @locked_tables = []
    @mutex = Mutex.new
    setup_threads(num_threads)
  end

  def setup_threads(num_threads)
    @threads = []
    num_threads.times do |index|
      @threads << DartReducerWorkerThread.new(@master_queue, @locked_tables, @mutex, index + 1)
    end
  end

  def shutdown
    @threads.each {|thread| thread.shutdown}
    @threads.each {|thread| thread.join}
  end

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

  def start
    begin
      while true
        time_start = Time.now

        # Find base tables that need to be minute reduced
        base_tables = []
        ActiveRecord::Base.connection.tables.each do |table|
          if table.to_s =~ /^t(\d+)_(\d+)$/
            packet_config_id = $1.to_i
            table_index = $2.to_i

            model = get_table_model(table)
            minute_model = get_table_model(table, "_m")
            hour_model = get_table_model(table, "_h")
            day_model = get_table_model(table, "_d")

            thread_queue = @master_queue.pop
            unless @locked_tables.include?([:MINUTE, packet_config_id, table_index])
              @mutex.synchronize do
                @locked_tables << ([:MINUTE, packet_config_id, table_index])
              end
              thread_queue << [:MINUTE, packet_config_id, table_index, model, minute_model]
            end
            thread_queue = @master_queue.pop
            unless @locked_tables.include?([:HOUR, packet_config_id, table_index])
              @mutex.synchronize do
                @locked_tables << ([:HOUR, packet_config_id, table_index])
              end
              thread_queue << [:HOUR, packet_config_id, table_index, minute_model, hour_model]
            end
            thread_queue = @master_queue.pop
            unless @locked_tables.include?([:DAY, packet_config_id, table_index])
              @mutex.synchronize do
                @locked_tables << ([:DAY, packet_config_id, table_index])
              end
              thread_queue << [:DAY, packet_config_id, table_index, hour_model, day_model]
            end
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

end # class DartWorker

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