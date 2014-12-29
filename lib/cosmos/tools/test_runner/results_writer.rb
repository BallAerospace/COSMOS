# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/script'
require 'zip'
require 'cosmos/gui/dialogs/set_tlm_dialog'

module Cosmos

  class ResultsWriter
    attr_reader :filename
    attr_accessor :data_package
    attr_accessor :metadata
    attr_accessor :auto_cycle_logs

    TIME_TOLERANCE = 5.0

    def initialize
      @filename = nil
      @file = nil
      @context = nil
      @path = System.paths['LOGS']
      @start_time = nil
      @stop_time = nil
      @results = nil
      @settings = nil
      @data_package = false
      @canceled = false
      @metadata = nil
      @auto_cycle_logs = false
    end

    def start(test_type, test_suite_class, test_class = nil, test_case = nil, settings = nil)
      @results = []
      @start_time = Time.now
      @filename = File.join(@path, File.build_timestamped_filename(['testrunner', 'results']))
      @data_package_filename = @filename[0..-5] + '.zip'
      Cosmos.set_working_dir do
        @file = File.new(@filename, 'w')
      end
      @settings = settings
      @canceled = false

      if test_case
        # Executing a single test case
        @context = "#{test_suite_class.name}:#{test_class.name}:#{test_case} #{test_type}"
      elsif test_class
        # Executing an entire test
        @context = "#{test_suite_class.name}:#{test_class.name} #{test_type}"
      else
        # Executing a test suite
        @context = "#{test_suite_class.name} #{test_type}"
      end

      cycle_logs() if @auto_cycle_logs

      header()
    end

    # process_result can handle an array of CosmosTestResult objects
    # or a single CosmosTestResult object
    def process_result(results)
      cosmos_lib = Regexp.new(File.join(Cosmos::PATH, 'lib'))
      # If we were passed an array we concat it to the results global
      if results.is_a? Array
        @results.concat(results)
      # A single result is appended and then turned into an array
      else
        @results << results
        results = [results]
      end
      # Process all the results (may be just one)
      results.each do |result|
        self.puts("#{result.test}:#{result.test_case}:#{result.result}")
        if result.message
          result.message.each_line do |line|
            if line =~ /[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F-\xFF]/
              line.chomp!
              line = line.inspect.remove_quotes
            end
            @file.puts '  ' + line
          end
          @file.flush
        end
        if result.exceptions
          @file.puts "  Exceptions:"
          result.exceptions.each_with_index do |error, index|
            error.formatted(true).each_line do |line|
              break if line =~ /cosmos_test.rb/
              next  if line =~ cosmos_lib
              if line =~ /[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F-\xFF]/
                line.chomp!
                line = line.inspect.remove_quotes
                line << "\n"
              end
              @file.print '    ' + line
            end
            @file.puts '' if index != (result.exceptions.length - 1)
          end
          @file.flush
        end
      end
    end

    def complete
      @stop_time = Time.now
      cycle_logs() if @auto_cycle_logs
      footer()
    ensure
      @file.close if @file and not @file.closed?
    end

    def header
      @file.puts "--- Test Report ---"
      @file.puts ''
      @file.puts "Files:"
      @file.puts "Report Filename: #{@filename}"
      @file.puts "Detailed Test Output Logged to: #{get_scriptrunner_message_log_filename()}"
      if @metadata
        begin
          items = get_tlm_packet(@metadata[0], @metadata[1])
          @file.puts ''
          @file.puts "Metadata:"
          items.each do |item_name, item_value, _|
            next if SetTlmDialog::IGNORED_ITEMS.include?(item_name)
            @file.puts "#{item_name} = #{item_value}"
          end
        rescue DRb::DRbConnError
          # Oh well
        end
      end
      if @settings
        @file.puts ''
        @file.puts "Settings:"
        @settings.each { |setting_name, setting_value| @file.puts "#{setting_name} = #{setting_value}" }
      end
      @file.puts ''
      @file.puts "Results:"
      self.puts "Executing #{@context}"
    end

    def create_data_package(progress_dialog = nil)
      if @data_package
        progress_dialog.cancel_callback = method(:cancel_callback) if progress_dialog
        progress_dialog.enable_cancel_button if progress_dialog

        begin
          Cosmos.set_working_dir do
            file_list = data_package_files()
            Zip::File.open(@data_package_filename, Zip::File::CREATE) do|zf|
              count = 0
              file_list.each do |file|
                break if @canceled
                count += 1
                if File.exist?(file) and File.size(file) > 0
                  zf.add(File.basename(file), file)
                  progress_dialog.set_overall_progress(count / (file_list.length).to_f) if progress_dialog
                end
              end
            end
          end
          progress_dialog.close_done if progress_dialog
        rescue => error
          progress_dialog.append_text("Error creating data package:\n#{error.formatted}\n") if progress_dialog
        ensure
          progress_dialog.set_overall_progress(1.0) if progress_dialog and !@canceled
          progress_dialog.complete if progress_dialog
        end
      end
    end

    def data_package_files
      # Grab data files that were created during test
      file_list = []
      Cosmos.set_working_dir do
        if File.exist?(@path)
          dir = Dir.new(@path)
          dir.each do |file|
            path = File.join(@path, file)
            unless FileTest.directory?(path)
              file_time = File.ctime(path)
              if file_time >= (@start_time - TIME_TOLERANCE) and file_time <= (@stop_time + TIME_TOLERANCE)
                file_list << path
              end
            end
          end
        end
      end
      file_list
    end

    # @param progress_dialog [ProgressDialog] The dialog that was cancelled
    def cancel_callback(progress_dialog = nil)
      @canceled = true
      return true, false
    end

    def footer
      self.puts "Completed #{@context}"

      @file.puts ''
      @file.puts "--- Test Summary ---"
      @file.puts ''

      pass_count = 0
      skip_count = 0
      fail_count = 0
      stopped    = false
      @results.each do |result|
        if result.result == :PASS
          pass_count += 1
        elsif result.result == :SKIP
          skip_count += 1
        elsif result.result == :FAIL
          fail_count += 1
        end

        if result.stopped
          stopped = true
        end
      end
      run_time = Time.format_seconds(@stop_time - @start_time)
      run_time += " (#{@stop_time - @start_time} seconds)" if @stop_time-@start_time > 60
      @file.puts("Run Time : #{run_time}")
      @file.puts("Total Tests : #{@results.length}")
      @file.puts("Pass : #{pass_count}")
      @file.puts("Skip : #{skip_count}")
      @file.puts("Fail : #{fail_count}")
      @file.puts('')
      if stopped
        @file.puts '*** Test was stopped prematurely ***'
        @file.puts ''
      end
      @file.flush
    end

    def write(string)
      @file.write(Time.now.formatted + ': ' + string)
      @file.flush
    end

    def puts(string)
      @file.puts(Time.now.formatted + ': ' + string)
      @file.flush
    end

    def collect_metadata(parent = nil)
      success = true
      if @metadata
        Qt.execute_in_main_thread(true) do
          begin
            success = SetTlmDialog.execute(parent, 'Enter Test Metadata', 'Start Test', 'Cancel Test', @metadata[0], @metadata[1])
          rescue DRb::DRbConnError
            success = false
            Qt::MessageBox.critical(parent, 'Error', 'Error Connecting to Command and Telemetry Server')
          rescue Exception => err
            Cosmos.handle_fatal_exception(err)
          end
        end
      end
      success
    end

    def cycle_logs
      begin
        start_new_server_message_log()
        start_logging()
      rescue DRb::DRbConnError
        # Oh well - Probably running a test that does not use realtime data
      end
    end

  end

end # module Cosmos
