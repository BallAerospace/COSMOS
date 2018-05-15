# encoding: ascii-8bit

# Copyright 2018 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/qt'
require 'cosmos/io/json_drb_object'

module Cosmos

  # Thread used to gather telemetry from DART and process it using a TabbedPlotsDefinition
  class TabbedPlotsDartThread
    # Array of exceptions that occurred
    attr_reader :errors

    # Create a new TabbedPlotsLogfileThread
    def initialize(tabbed_plots_config, progress_dialog = nil, time_start = nil, time_end = nil, meta_filters = [])
      super()
      @tabbed_plots_config = tabbed_plots_config
      @errors = []
      @done = false
      @cancel = false

      if progress_dialog
        progress_dialog.cancel_callback = method(:kill)
        progress_dialog.enable_cancel_button
      end

      @thread = Thread.new do
        begin
          # Determine required queries for DART
          required_queries = []
          @tabbed_plots_config.mu_synchronize do
            @tabbed_plots_config.each_data_object do |data_object|
              required_queries.concat(data_object.processed_items)
            end
          end
          required_queries.uniq!

          # Execute each query
          results = {}
          server = JsonDRbObject.new(System.connect_hosts['DART_DECOM'], System.ports['DART_DECOM'])
          time_start = Time.utc(1970, 1, 1) unless time_start
          time_end = Time.now unless time_end
          progress_dialog.set_step_progress(0) if progress_dialog
          index = 0
          query_string = ""
          required_queries.each do |target_name, packet_name, item_name, value_type, array_index, dart_reduction, dart_reduced_type|
            begin
              break if @cancel
              value_type = :CONVERTED if !value_type or value_type != :RAW
              # TODO: Support FORMATTED and WITH_UNITS by iterating and modifying results
              query_string = "#{target_name} #{packet_name} #{item_name} #{value_type} #{array_index} #{dart_reduction} #{dart_reduced_type}"
              progress_dialog.append_text("Querying #{query_string}") if progress_dialog
              request = {}
              request['start_time_sec'] = time_start.tv_sec
              request['start_time_usec'] = time_start.tv_usec
              request['end_time_sec'] = time_end.tv_sec
              request['end_time_usec'] = time_end.tv_usec
              request['item'] = [target_name, packet_name, item_name]
              request['reduction'] = dart_reduction.to_s
              request['cmd_tlm'] = 'TLM'
              request['offset'] = 0
              request['limit'] = 10000
              if dart_reduction == :NONE
                request['value_type'] = value_type.to_s
              else
                request['value_type'] = value_type.to_s + "_#{dart_reduced_type}"
              end
              request['meta_filters'] = meta_filters unless meta_filters.empty?
              query_result = server.query(request)
              result = query_result
              if array_index
                result = []
                query_result.each do |qr|
                  result << [qr[0][array_index], qr[1], qr[2], qr[3], qr[4]]
                end
              end
              results[query_string] = result
              progress_dialog.append_text("  Received #{result.length} values") if progress_dialog
              progress_dialog.set_step_progress((index + 1).to_f / required_queries.length) if progress_dialog
            rescue Exception => error
              @errors << error
              break if @cancel
              progress_dialog.append_text("Error querying #{query_string} : #{error.class}:#{error.message}\n#{error.backtrace.join("\n")}\n") if progress_dialog
              # If a progress dialog is shown we can't just bail on this error or
              # it will close and the user will have no idea what happened
              # Thus we'll spin here waiting for them to close the dialog
              break if @cancel
              if progress_dialog
                sleep(0.1) until progress_dialog.complete?
              end
              break # Bail out because something bad happened
            end
            index += 1
          end
          progress_dialog.set_step_progress(1.0) if progress_dialog and not @cancel
          progress_dialog.set_overall_progress(0.5) if progress_dialog and not @cancel

          # Fill each data object with the DART data
          # For now assume all results are time correlated (they should be)
          @tabbed_plots_config.mu_synchronize do
            @tabbed_plots_config.each_data_object do |data_object|
              do_results = []
              data_object.processed_items.each do |target_name, packet_name, item_name, value_type, array_index, dart_reduction, dart_reduced_type|
                query_string = "#{target_name} #{packet_name} #{item_name} #{value_type} #{array_index} #{dart_reduction} #{dart_reduced_type}"
                do_results << results[query_string]
              end
              data_object.process_dart(do_results)
            end
          end

        rescue Exception => error
          @errors << error
          return if @cancel
          progress_dialog.append_text("DART Thread Error #{error.class}:#{error.message}\n#{error.backtrace.join("\n")}\n") if progress_dialog
          # If a progress dialog is shown we can't just bail on this error or
          # it will close and the user will have no idea what happened
          # Thus we'll spin here waiting for them to close the dialog
          if progress_dialog
            sleep(0.1) until progress_dialog.complete? or @cancel
          end
        ensure
          if !@cancel
            progress_dialog.complete if progress_dialog
            sleep(0.1) # Give the user a chance to see something if we process really fast
          end
          @done = true
        end
      end
    end # def initialize

    # Indicates if processing is complete
    def done?
      @done
    end

    # Kills the log file processing thread
    def kill(progress_dialog = nil)
      @cancel = true
      Cosmos.kill_thread(self, @thread)
      progress_dialog.complete if progress_dialog
      @thread = nil
      @done = true
      return true, false
    end # def kill

    def graceful_kill
      # Just to remove warnings
    end

  end # class TabbedPlotsLogfileThread

end # module Cosmos
