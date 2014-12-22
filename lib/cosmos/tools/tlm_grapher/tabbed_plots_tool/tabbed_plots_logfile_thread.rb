# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/qt'

module Cosmos

  # Thread used to gather telemetry from log file(s) and process it using a TabbedPlotsDefinition
  class TabbedPlotsLogfileThread
    # Number of packets between updating the progress bar
    PROGRESS_UPDATE_PACKET_COUNT = 100

    # Array of exceptions that occurred processing the log file
    attr_reader :errors

    # Create a new TabbedPlotsLogfileThread
    def initialize(log_files, packet_log_reader, tabbed_plots_config, progress_dialog = nil, time_start = nil, time_end = nil)
      super()
      @packet_log_reader = packet_log_reader
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
          log_file_count = 1
          log_files.each do |log_file|
            break if @cancel
            begin
              file_size = File.size(log_file).to_f
              progress_dialog.append_text("Procesing File #{log_file_count}/#{log_files.length}: #{log_file}\n") if progress_dialog
              progress_dialog.set_step_progress(0) if progress_dialog
              packet_count = 0
              @packet_log_reader.each(log_file, true, time_start, time_end) do |packet|
                break if @cancel
                if progress_dialog and packet_count % PROGRESS_UPDATE_PACKET_COUNT == 0
                  progress_dialog.set_step_progress(@packet_log_reader.bytes_read / file_size)
                end
                @tabbed_plots_config.process_packet(packet)
                packet_count += 1
              end
              progress_dialog.set_step_progress(1.0) if progress_dialog and not @cancel
              progress_dialog.set_overall_progress(log_file_count.to_f / log_files.length.to_f) if progress_dialog and not @cancel
            rescue Exception => error
              @errors << error
              progress_dialog.append_text("Error processing #{log_file}:\n#{error.class} : #{error.message}\n#{error.backtrace.join("\n")}\n", 2) if progress_dialog
              # If a progress dialog is shown we can't just bail on this error or
              # it will close and the user will have no idea what happened
              # Thus we'll spin here waiting for them to close the dialog
              if progress_dialog
                sleep(0.1) until progress_dialog.complete?
              end
              break # Bail out because something bad happened
            end
            log_file_count += 1
          end
        ensure
          progress_dialog.complete if progress_dialog
          sleep(0.1) # Give the user a chance to see something if we process really fast
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
      @thread.kill
      @thread = nil
      @done = true
      return true, false
    end # def kill

  end # class TabbedPlotsLogfileThread

end # module Cosmos
