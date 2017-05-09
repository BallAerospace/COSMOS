# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  # Class to analyze log files and report packet counts.
  class AnalyzeLog

    def initialize(parent, packet_log_frame)
      @parent = parent
      @packet_log_frame = packet_log_frame
      @input_filenames = []
      @packet_log_reader = System.default_packet_log_reader.new
      @time_start = nil
      @time_end = nil
      @cancel = false
    end

    def analyze_log_files
      @cancel = false
      pkt_counts = {}
      begin
        @packet_log_reader = @packet_log_frame.packet_log_reader
        @input_filenames = @packet_log_frame.filenames.sort
        @time_start = @packet_log_frame.time_start
        @time_end = @packet_log_frame.time_end
        unless @input_filenames and @input_filenames[0]
          Qt::MessageBox.critical(@parent, 'Error', 'Please select at least 1 input file')
          return
        end

        ProgressDialog.execute(@parent, # parent
                               'Log File Progress', # title
                               600, # width, height
                               300) do |progress_dialog|
          progress_dialog.cancel_callback = method(:cancel_callback)
          progress_dialog.enable_cancel_button

          begin
            Cosmos.set_working_dir do
              pkt_counts = analyze_files(progress_dialog)
            end
          ensure
            progress_dialog.complete
          end
        end

        if !@cancel
          results = "Log Analysis Complete.\n"
          results << "Log Reader: #{@packet_log_reader.class.to_s}\n"
          if @time_start
            results << "Start time: #{@time_start.formatted}\n"
          else
            results << "Start time: not specified\n"
          end
          if @time_end
            results << "End time:   #{@time_end.formatted}\n"
          else
            results << "End time:   not specified\n"
          end
          results << "\n"

          if pkt_counts.empty?
            results << "No files analyzed"
          else
            if pkt_counts.keys.size > 1
              pkt_counts_total = {}
              pkt_counts.each do |file, counts|
                counts.each do |pkt, count|
                  pkt_counts_total[pkt] ||= 0
                  pkt_counts_total[pkt] += count
                end
              end
              results << "Total count of packets found in all files:\n"
              pkt_counts_total.keys.sort.each do |pkt|
                results << "#{pkt}: #{pkt_counts_total[pkt]}\n"
              end
              results << "\n"
            end

            pkt_counts.each do |file, counts|
              results << "Packets found in file: #{file}\n"
              if counts.empty?
                results << "  No packets found\n"
              else
                counts.keys.sort.each do |pkt|
                  results << "#{pkt}: #{counts[pkt]}\n"
                end
              end
              results << "\n"
            end
          end
          ScrollTextDialog.new(@parent, 'Packet Counts', results)
        end

      rescue => error
        Qt::MessageBox.critical(@parent, 'Error!', "Error Analyzing Log File(s)\n#{error.formatted}")
      end
    end

    def analyze_files(progress_dialog)
      log_file_count = 1
      pkt_counts = {}
      @input_filenames.each do |log_file|
        break if @cancel
        begin
          Cosmos.check_log_configuration(@packet_log_reader, log_file)
          file_size = File.size(log_file).to_f
          progress_dialog.append_text("Analyzing File #{log_file_count}/#{@input_filenames.length}: #{log_file}")
          progress_dialog.set_step_progress(0.0)
          @packet_log_reader.each(
            log_file, # log filename
            true,     # identify and define packet
            @time_start,
            @time_end) do |packet|

            break if @cancel
            progress_dialog.set_step_progress(@packet_log_reader.bytes_read / file_size)
            pkt_counts[log_file] ||= {}
            pkt_counts[log_file]["#{packet.target_name} #{packet.packet_name}"] ||= 0
            pkt_counts[log_file]["#{packet.target_name} #{packet.packet_name}"] += 1       
          end
          progress_dialog.set_step_progress(1.0) if !@cancel
          progress_dialog.set_overall_progress(log_file_count.to_f / @input_filenames.length.to_f) if !@cancel
        rescue Exception => error
          progress_dialog.append_text("Error analyzing: #{error.formatted}\n")
        end
        log_file_count += 1
      end
      return pkt_counts
    end

    def cancel_callback(progress_dialog = nil)
      @cancel = true
      return true, false
    end

    def self.execute(parent, packet_log_frame)
      log_analyzer = AnalyzeLog.new(parent, packet_log_frame)
      log_analyzer.analyze_log_files()
    end


  end # class AnalyzeLog

end # module Cosmos
