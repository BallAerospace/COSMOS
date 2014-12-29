# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/io/stderr'
require 'cosmos/io/stdout'

module Cosmos

  class TestStatus
    attr_accessor :status
    attr_accessor :pass_count
    attr_accessor :skip_count
    attr_accessor :fail_count
    attr_reader :total

    @@instance = nil

    def initialize
      @status = ''
      @pass_count = 0
      @skip_count = 0
      @fail_count = 0
      @total = 1
    end

    def total= (new_total)
      if new_total <= 0
        @total = 1
      else
        @total = new_total
      end
    end

    def self.instance
      @@instance = self.new unless @@instance
      @@instance
    end
  end # class TestStatus

  class TestResult
    attr_accessor :test
    attr_accessor :test_case
    attr_accessor :output
    attr_accessor :exceptions
    attr_accessor :stopped
    attr_accessor :result
    attr_accessor :message

    def initialize
      @test = nil
      @test_case = nil
      @output = nil
      @exceptions = nil
      @stopped = false
      @result = :SKIP
      @message = nil
    end
  end # class TestResult

  # TestGroup class
  #
  class Test

    @@abort_on_exception = false
    @@current_test_result = nil

    def initialize
      @output_io = StringIO.new('', 'r+')
      $stdout = Stdout.instance
      $stderr = Stderr.instance
    end

    def self.abort_on_exception
      @@abort_on_exception
    end

    def self.abort_on_exception=(value)
      @@abort_on_exception = value
    end

    def self.test_cases
      # Find all the test cases
      test_cases = []
      self.instance_methods.each do |method_name|
        if method_name.to_s =~ /^test/
          test_cases << method_name.to_s
        end
      end

      # Sort by name
      test_cases.sort!

      test_cases
    end

    # Name of the test
    def name
      if self.class != Test
        self.class.to_s
      else
        'UnnamedTest'
      end
    end

    # Run all the test cases
    def run
      results = []

      # Setup the test
      result = run_setup()
      if result
        results << result
        yield result if block_given?
        raise StopScript if result.stopped
      end

      # Run each test case
      self.class.test_cases.each do |test_case|
        results << run_test_case(test_case)
        yield results[-1] if block_given?
        raise StopScript if (results[-1].exceptions and @@abort_on_exception) or results[-1].stopped
      end

      # Teardown the test
      result = run_teardown()
      if result
        results << result
        yield result if block_given?
        raise StopScript if result.stopped
      end

      results
    end

    # Run a specific test case
    def run_test_case (test_case)
      TestStatus.instance.status = "#{self.class} : #{test_case}"
      run_function(self, test_case)
    end

    def run_function (object, method_name)
      # Convert to a symbol to use as a method_name
      method_name = method_name.to_s.intern unless method_name.class == Symbol

      # Create the test result
      result = TestResult.new
      @@current_test_result = result

      # Verify test case exists
      if object.class.method_defined?(method_name)
        # Capture STDOUT and STDERR
        $stdout.add_stream(@output_io)
        $stderr.add_stream(@output_io)

        result.test      = object.class.to_s
        result.test_case = method_name.to_s
        begin
          if defined? ScriptRunnerFrame
            if ScriptRunnerFrame.instance
              ScriptRunnerFrame.instance.select_tab_and_destroy_tabs_after_index(0)
            end
          end

          object.send(method_name)
          result.result = :PASS

          if defined? ScriptRunnerFrame
            if ScriptRunnerFrame.instance and ScriptRunnerFrame.instance.exceptions
              result.exceptions = ScriptRunnerFrame.instance.exceptions
              result.result     = :FAIL
              ScriptRunnerFrame.instance.exceptions = nil
            end
          end
        rescue StandardError, SyntaxError => error
          if error.class == StopScript
            result.stopped = true
            result.result  = :STOP
          end
          if error.class == SkipTestCase
            result.result  = :SKIP
            result.message ||= ''
            result.message << error.message
          else
            if defined? ScriptRunnerFrame
              if error.class != StopScript and
                (not ScriptRunnerFrame.instance or
                 not ScriptRunnerFrame.instance.exceptions or
                 not ScriptRunnerFrame.instance.exceptions.include? error)
                result.exceptions ||= []
                result.exceptions << error
                puts "*** Exception in Control Statement:"
                error.formatted.each_line do |line|
                  break if line =~ /test_runner.test.rb/
                  puts '  ' + line
                end
              end
              if ScriptRunnerFrame.instance and ScriptRunnerFrame.instance.exceptions
                result.exceptions ||= []
                result.exceptions.concat(ScriptRunnerFrame.instance.exceptions)
                ScriptRunnerFrame.instance.exceptions = nil
              end
            elsif error.class != StopScript
              result.exceptions ||= []
              result.exceptions << error
            end

            result.result = :FAIL if result.exceptions
          end
        ensure
          result.output     = @output_io.string
          @output_io.string = ''
          $stdout.remove_stream(@output_io)
          $stderr.remove_stream(@output_io)

          case result.result
          when :FAIL
            TestStatus.instance.fail_count += 1
          when :SKIP
            TestStatus.instance.skip_count += 1
          when :PASS
            TestStatus.instance.pass_count += 1
          end
        end

      else
        @@current_test_result = nil
        raise "Unknown method #{method_name} for #{object.class}"
      end

      @@current_test_result = nil
      result
    end

    def run_setup
      result = nil
      if self.class.method_defined?(:setup)
        TestStatus.instance.status = "#{self.class} : setup"
        result = run_test_case(:setup)
      end
      result
    end

    def run_teardown
      result = nil
      if self.class.method_defined?(:teardown)
        TestStatus.instance.status = "#{self.class} : teardown"
        result = run_test_case(:teardown)
      end
      result
    end

    def self.get_num_tests
      num_tests = 0
      num_tests += 1 if self.method_defined?(:setup)
      num_tests += 1 if self.method_defined?(:teardown)
      num_tests += self.test_cases.length
      num_tests
    end

    def self.puts (string)
      $stdout.puts string
      if @@current_test_result
        @@current_test_result.message ||= ''
        @@current_test_result.message << string.chomp
        @@current_test_result.message << "\n"
      end
    end
  end # class Test

  class TestSuite
    attr_reader :tests
    attr_reader :plans

    def initialize
      @tests = {}
      @plans = []
    end

    def <=> (other_test_suite)
      self.name <=> other_test_suite.name
    end

    # Name of the test suite
    def name
      if self.class != TestSuite
        self.class.to_s
      else
        'UnassignedTestSuite'
      end
    end

    # Add a test to the suite
    def add_test (test_class)
      test_class = Object.const_get(test_class.to_s.intern) unless test_class.class == Class
      @tests[test_class] = test_class.new unless @tests[test_class]
      @plans << [:TEST, test_class, nil]
    end

    # Add a test case to the suite
    def add_test_case (test_class, test_case)
      test_class = Object.const_get(test_class.to_s.intern) unless test_class.class == Class
      @tests[test_class] = test_class.new unless @tests[test_class]
      @plans << [:TEST_CASE, test_class, test_case]
    end

    # Add a test setup to the suite
    def add_test_setup (test_class)
      test_class = Object.const_get(test_class.to_s.intern) unless test_class.class == Class
      @tests[test_class] = test_class.new unless @tests[test_class]
      @plans << [:TEST_SETUP, test_class, nil]
    end

    # Add a test teardown to the suite
    def add_test_teardown (test_class)
      test_class = Object.const_get(test_class.to_s.intern) unless test_class.class == Class
      @tests[test_class] = test_class.new unless @tests[test_class]
      @plans << [:TEST_TEARDOWN, test_class, nil]
    end

    # Run all the tests
    def run (&block)
      TestStatus.instance.total = get_num_tests()
      results = []

      # Setup the test suite
      result = run_setup(true)
      if result
        results << result
        yield result if block_given?
        raise StopScript if result.stopped
      end

      # Run each test
      @plans.each do |test_type, test_class, test_case|
        case test_type
        when :TEST
          results.concat(run_test(test_class, true, &block))
        when :TEST_CASE
          result = run_test_case(test_class, test_case, true)
          results << result
          yield result if block_given?
        when :TEST_SETUP
          result = run_test_setup(test_class, true)
          if result
            results << result
            yield result if block_given?
          end
        when :TEST_TEARDOWN
          result = run_test_teardown(test_class, true)
          if result
            results << result
            yield result if block_given?
          end
        end
      end

      # Teardown the test suite
      result = run_teardown(true)
      if result
        results << result
        yield result if block_given?
        raise StopScript if result.stopped
      end

      results
    end

    # Run a specific test
    def run_test (test_class, internal = false, &block)
      # Determine if this test_class is in the plan and the number of tests associated with this test_class
      in_plan = false
      num_tests = 0
      @plans.each do |plan_test_type, plan_test_class, plan_test_case|
        if plan_test_type == :TEST and test_class == plan_test_class
          in_plan = true
        end
        if (plan_test_type == :TEST_SETUP and test_class == plan_test_class) or
           (plan_test_type == :TEST_TEARDOWN and test_class == plan_test_class) or
           (plan_test_case and test_class == plan_test_class)
          num_tests += 1
        end
      end

      if in_plan
        TestStatus.instance.total = test_class.get_num_tests() unless internal
        results = @tests[test_class].run(&block)
      else
        results = []
        TestStatus.instance.total = num_tests unless internal

        # Run each setup, teardown, or test_case associated with this test_class in the order
        # defined in the plan
        @plans.each do |plan_test_type, plan_test_class, plan_test_case|
          if plan_test_class == test_class
            case plan_test_type
            when :TEST_CASE
              result = run_test_case(plan_test_class, plan_test_case, true)
              results << result
              yield result if block_given?
            when :TEST_SETUP
              result = run_test_setup(plan_test_class, true)
              if result
                results << result
                yield result if block_given?
              end
            when :TEST_TEARDOWN
              result = run_test_teardown(plan_test_class, true)
              if result
                results << result
                yield result if block_given?
              end
            end
          end
        end
      end

      return results
    end

    # Run a specific test case
    def run_test_case (test_class, test_case, internal = false)
      TestStatus.instance.total = 1 unless internal
      @tests[test_class].run_test_case(test_case)
    end

    def run_setup (internal = false)
      result = nil
      if self.class.method_defined?(:setup) and @tests.length > 0
        TestStatus.instance.total = 1 unless internal
        TestStatus.instance.status = "#{self.class} : setup"
        result = @tests[@tests.keys[0]].run_function(self, :setup)
      end
      result
    end

    def run_teardown (internal = false)
      result = nil
      if self.class.method_defined?(:teardown) and @tests.length > 0
        TestStatus.instance.total = 1 unless internal
        TestStatus.instance.status = "#{self.class} : teardown"
        result = @tests[@tests.keys[0]].run_function(self, :teardown)
      end
      result
    end

    def run_test_setup (test_class, internal = false)
      TestStatus.instance.total = 1 unless internal
      @tests[test_class].run_setup
    end

    def run_test_teardown (test_class, internal = false)
      TestStatus.instance.total = 1 unless internal
      @tests[test_class].run_teardown
    end

    def get_num_tests
      num_tests = 0
      @plans.each do |test_type, test_class, test_case|
        case test_type
        when :TEST
          num_tests += test_class.get_num_tests
        when :TEST_CASE, :TEST_SETUP, :TEST_TEARDOWN
          num_tests += 1
        end
      end
      num_tests += 1 if self.class.method_defined?(:setup)
      num_tests += 1 if self.class.method_defined?(:teardown)
      num_tests
    end
  end # class TestSuite

end # module Cosmos
