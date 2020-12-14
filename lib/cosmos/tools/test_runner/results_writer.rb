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

module Cosmos
  class ResultsWriter
    attr_accessor :metadata

    TIME_TOLERANCE = 5.0

    def initialize
      @report = nil
      @context = nil
      @start_time = nil
      @stop_time = nil
      @results = nil
      @settings = nil
      @metadata = nil
    end

    def start(test_type, test_suite_class, test_class = nil, test_case = nil, settings = nil)
      @results = []
      @start_time = Time.now.sys
      @settings = settings
      @report = []

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
            @report << '  ' + line
          end
        end
        if result.exceptions
          @report << "  Exceptions:"
          result.exceptions.each_with_index do |error, index|
            error.formatted(true).each_line do |line|
              break if line =~ /test_runner\/test.rb/
              next  if line =~ cosmos_lib
              if line =~ /[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F-\xFF]/
                line.chomp!
                line = line.inspect.remove_quotes
                line << "\n"
              end
              @report << '    ' + line
            end
            @report << '' if index != (result.exceptions.length - 1)
          end
        end
      end
    end

    def complete
      @stop_time = Time.now.sys
      footer()
    end

    def report
      @report.join("\n")
    end

    def header
      @report << "--- Test Report ---"
      # @report << ''
      # if @metadata
      #   begin
      #     items = get_tlm_packet('SYSTEM', 'META')
      #     @report << ''
      #     @report << "Metadata:"
      #     items.each do |item_name, item_value, _|
      #       next if SetTlmDialog::IGNORED_ITEMS.include?(item_name)
      #       @report << "#{item_name} = #{item_value}"
      #     end
      #   rescue DRb::DRbConnError
      #     # Oh well
      #   end
      # end
      if @settings
        @report << ''
        @report << "Settings:"
        @settings.each { |setting_name, setting_value| @report << "#{setting_name} = #{setting_value}" }
      end
      @report << ''
      @report << "Results:"
      self.puts "Executing #{@context}"
    end

    def footer
      self.puts "Completed #{@context}"

      @report << ''
      @report << "--- Test Summary ---"
      @report << ''

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
      run_time << " (#{@stop_time - @start_time} seconds)" if @stop_time-@start_time > 60
      @report << "Run Time : #{run_time}"
      @report << "Total Tests : #{@results.length}"
      @report << "Pass : #{pass_count}"
      @report << "Skip : #{skip_count}"
      @report << "Fail : #{fail_count}"
      @report << ''
      if stopped
        @report << '*** Test was stopped prematurely ***'
        @report << ''
      end
    end

    def write(string)
      @report << Time.now.sys.formatted + ': ' + string
    end

    def puts(string)
      @report << Time.now.sys.formatted + ': ' + string
    end

    # def collect_metadata(parent = nil)
    #   success = true
    #   if @metadata
    #     Qt.execute_in_main_thread(true) do
    #       begin
    #         success = SetTlmDialog.execute(parent, 'Enter Test Metadata', 'Start Test', 'Cancel Test', 'SYSTEM', 'META')
    #       rescue DRb::DRbConnError
    #         success = false
    #         Qt::MessageBox.critical(parent, 'Error', 'Error Connecting to Command and Telemetry Server')
    #       rescue Exception => err
    #         Cosmos.handle_fatal_exception(err)
    #       end
    #     end
    #   end
    #   success
    # end
  end
end
