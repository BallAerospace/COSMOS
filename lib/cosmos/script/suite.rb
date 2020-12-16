# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/core_ext/stringio'
require 'cosmos/io/stderr'
require 'cosmos/io/stdout'

module Cosmos
  # Error raised when a Script should be stopped
  class StopScript < StandardError; end
  # Error raised when a Script should be skipped
  class SkipScript < StandardError; end

  # Base class for Script Runner suites. COSMOS Suites inherit from Suite
  # and can implement setup and teardown methods. Script groups are added via add_group(Group)
  # and individual scripts added via add_script(Group, script_method).
  class Suite
    attr_reader :scripts
    attr_reader :plans

    ###########################################################################
    # START PUBLIC API
    ###########################################################################

    # Create a new Suite
    def initialize
      @scripts = {}
      @plans = []
    end

    # Add a group to the suite
    def add_group(group_class)
      group_class = Object.const_get(group_class.to_s.intern) unless group_class.class == Class
      @scripts[group_class] = group_class.new unless @scripts[group_class]
      @plans << [:GROUP, group_class, nil]
    end

    # Add a script to the suite
    def add_script(group_class, script)
      group_class = Object.const_get(group_class.to_s.intern) unless group_class.class == Class
      @scripts[group_class] = group_class.new unless @scripts[group_class]
      @plans << [:SCRIPT, group_class, script]
    end

    # Add a group setup to the suite
    def add_group_setup(group_class)
      group_class = Object.const_get(group_class.to_s.intern) unless group_class.class == Class
      @scripts[group_class] = group_class.new unless @scripts[group_class]
      @plans << [:GROUP_SETUP, group_class, nil]
    end

    # Add a group teardown to the suite
    def add_group_teardown(group_class)
      group_class = Object.const_get(group_class.to_s.intern) unless group_class.class == Class
      @scripts[group_class] = group_class.new unless @scripts[group_class]
      @plans << [:GROUP_TEARDOWN, group_class, nil]
    end

    ###########################################################################
    # END PUBLIC API
    ###########################################################################

    def <=>(other_suite)
      self.name <=> other_suite.name
    end

    # Name of the suite
    def name
      if self.class != Suite
        self.class.to_s.split('::')[-1]
      else
        'UnassignedSuite'
      end
    end

    # Returns the number of scripts in the suite including setup and teardown methods
    def get_num_scripts
      num_scripts = 0
      @plans.each do |type, group_class, script|
        case type
        when :GROUP
          num_scripts += group_class.get_num_scripts
        when :SCRIPT, :GROUP_SETUP, :GROUP_TEARDOWN
          num_scripts += 1
        end
      end
      num_scripts += 1 if self.class.method_defined?(:setup)
      num_scripts += 1 if self.class.method_defined?(:teardown)
      num_scripts
    end

    # Run all the scripts
    def run(&block)
      ScriptResult.suite = name()
      ScriptStatus.instance.total = get_num_scripts()
      results = []

      # Setup the suite
      result = run_setup(true)
      if result
        results << result
        yield result if block_given?
        raise StopScript if result.stopped
      end

      # Run each script
      @plans.each do |type, group_class, script|
        case type
        when :GROUP
          results.concat(run_group(group_class, true, &block))
        when :SCRIPT
          result = run_script(group_class, script, true)
          results << result
          yield result if block_given?
          raise StopScript if (result.exceptions and group_class.abort_on_exception) or result.stopped
        when :GROUP_SETUP
          result = run_group_setup(group_class, true)
          if result
            results << result
            yield result if block_given?
            raise StopScript if (result.exceptions and group_class.abort_on_exception) or result.stopped
          end
        when :GROUP_TEARDOWN
          result = run_group_teardown(group_class, true)
          if result
            results << result
            yield result if block_given?
            raise StopScript if (result.exceptions and group_class.abort_on_exception) or result.stopped
          end
        end
      end

      # Teardown the suite
      result = run_teardown(true)
      if result
        results << result
        yield result if block_given?
        raise StopScript if result.stopped
      end

      ScriptResult.suite = nil
      results
    end

    # Run a specific group
    def run_group(group_class, internal = false, &block)
      ScriptResult.suite = name() unless internal

      # Determine if this group_class is in the plan and the number of scripts associated with this group_class
      in_plan = false
      num_scripts = 0
      @plans.each do |plan_type, plan_group_class, plan_script|
        if plan_type == :GROUP and group_class == plan_group_class
          in_plan = true
        end
        if (plan_type == :GROUP_SETUP and group_class == plan_group_class) or
           (plan_type == :GROUP_TEARDOWN and group_class == plan_group_class) or
           (plan_script and group_class == plan_group_class)
          num_scripts += 1
        end
      end

      if in_plan
        ScriptStatus.instance.total = group_class.get_num_scripts() unless internal
        results = @scripts[group_class].run(&block)
      else
        results = []
        ScriptStatus.instance.total = num_scripts unless internal

        # Run each setup, teardown, or script associated with this group_class in the order
        # defined in the plan
        @plans.each do |plan_type, plan_group_class, plan_script|
          if plan_group_class == group_class
            case plan_type
            when :SCRIPT
              result = run_script(plan_group_class, plan_script, true)
              results << result
              yield result if block_given?
            when :GROUP_SETUP
              result = run_group_setup(plan_group_class, true)
              if result
                results << result
                yield result if block_given?
              end
            when :GROUP_TEARDOWN
              result = run_group_teardown(plan_group_class, true)
              if result
                results << result
                yield result if block_given?
              end
            end
          end
        end
      end

      ScriptResult.suite = nil unless internal
      return results
    end

    # Run a specific script
    def run_script(group_class, script, internal = false)
      ScriptResult.suite = name() unless internal
      ScriptStatus.instance.total = 1 unless internal
      result = @scripts[group_class].run_script(script)
      ScriptResult.suite = nil unless internal
      result
    end

    def run_setup(internal = false)
      ScriptResult.suite = name() unless internal
      result = nil
      if self.class.method_defined?(:setup) and @scripts.length > 0
        ScriptStatus.instance.total = 1 unless internal
        ScriptStatus.instance.status = "#{self.class} : setup"
        result = @scripts[@scripts.keys[0]].run_method(self, :setup)
      end
      ScriptResult.suite = nil unless internal
      result
    end

    def run_teardown(internal = false)
      ScriptResult.suite = name() unless internal
      result = nil
      if self.class.method_defined?(:teardown) and @scripts.length > 0
        ScriptStatus.instance.total = 1 unless internal
        ScriptStatus.instance.status = "#{self.class} : teardown"
        result = @scripts[@scripts.keys[0]].run_method(self, :teardown)
      end
      ScriptResult.suite = nil unless internal
      result
    end

    def run_group_setup(group_class, internal = false)
      ScriptResult.suite = name() unless internal
      ScriptStatus.instance.total = 1 unless internal
      result = @scripts[group_class].run_setup
      ScriptResult.suite = nil unless internal
      result
    end

    def run_group_teardown(group_class, internal = false)
      ScriptResult.suite = name() unless internal
      ScriptStatus.instance.total = 1 unless internal
      result = @scripts[group_class].run_teardown
      ScriptResult.suite = nil unless internal
      result
    end
  end

  # Base class for a group. All COSMOS Script Runner scripts should inherit Group
  # and then implement scripts methods starting with 'script_', 'test_', or 'op_'
  # e.g. script_mech_open, test_mech_open, op_mech_open.
  class Group
    @@abort_on_exception = false
    @@current_result = nil

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

    def self.scripts
      # Find all the script methods
      methods = []
      self.instance_methods.each do |method_name|
        if method_name.to_s =~ /^test|^script|op_/
          methods << method_name.to_s
        end
      end
      # Sort by name for all found methods
      methods.sort!
      methods
    end

    # Name of the script group
    def name
      if self.class != Group
        self.class.to_s.split('::')[-1]
      else
        'UnnamedGroup'
      end
    end

    # Run all the scripts
    def run
      results = []

      # Setup the script group
      result = run_setup()
      if result
        results << result
        yield result if block_given?
        raise StopScript if (results[-1].exceptions and @@abort_on_exception) or results[-1].stopped
      end

      # Run all the scripts
      self.class.scripts.each do |method_name|
        results << run_script(method_name)
        yield results[-1] if block_given?
        raise StopScript if (results[-1].exceptions and @@abort_on_exception) or results[-1].stopped
      end

      # Teardown the script group
      result = run_teardown()
      if result
        results << result
        yield result if block_given?
        raise StopScript if (results[-1].exceptions and @@abort_on_exception) or results[-1].stopped
      end

      results
    end

    # Run a specific script method
    def run_script(method_name)
      ScriptStatus.instance.status = "#{self.class} : #{method_name}"
      run_method(self, method_name)
    end

    def run_method(object, method_name)
      # Convert to a symbol to use as a method_name
      method_name = method_name.to_s.intern unless method_name.class == Symbol

      result = ScriptResult.new
      @@current_result = result

      # Verify script method exists
      if object.class.method_defined?(method_name)
        # Capture STDOUT and STDERR
        $stdout.add_stream(@output_io)
        $stderr.add_stream(@output_io)

        result.group = object.class.to_s.split('::')[-1]
        result.script = method_name.to_s
        begin
          object.send(method_name)
          result.result = :PASS

          if RunningScript.instance and RunningScript.instance.exceptions
            result.exceptions = RunningScript.instance.exceptions
            result.result     = :FAIL
            RunningScript.instance.exceptions = nil
          end
        rescue StandardError, SyntaxError => error
          # Check that the error belongs to the StopScript inheritance chain
          if error.class <= StopScript
            result.stopped = true
            result.result  = :STOP
          end
          # Check that the error belongs to the SkipScript inheritance chain
          if error.class <= SkipScript
            result.result  = :SKIP
            result.message ||= ''
            result.message << error.message + "\n"
          else
            if error.class != StopScript and
              (not RunningScript.instance or
                not RunningScript.instance.exceptions or
                not RunningScript.instance.exceptions.include? error)
              result.exceptions ||= []
              result.exceptions << error
              puts "*** Exception in Control Statement:"
              error.formatted.each_line do |line|
                puts '  ' + line
              end
            end
            if RunningScript.instance and RunningScript.instance.exceptions
              result.exceptions ||= []
              result.exceptions.concat(RunningScript.instance.exceptions)
              RunningScript.instance.exceptions = nil
            end
          end

          result.result = :FAIL if result.exceptions
        ensure
          result.output     = @output_io.string
          @output_io.string = ''
          $stdout.remove_stream(@output_io)
          $stderr.remove_stream(@output_io)

          case result.result
          when :FAIL
            ScriptStatus.instance.fail_count += 1
          when :SKIP
            ScriptStatus.instance.skip_count += 1
          when :PASS
            ScriptStatus.instance.pass_count += 1
          end
        end

      else
        @@current_result = nil
        raise "Unknown method #{method_name} for #{object.class}"
      end

      @@current_result = nil
      result
    end

    def run_setup
      result = nil
      if self.class.method_defined?(:setup)
        ScriptStatus.instance.status = "#{self.class} : setup"
        result = run_script(:setup)
      end
      result
    end

    def run_teardown
      result = nil
      if self.class.method_defined?(:teardown)
        ScriptStatus.instance.status = "#{self.class} : teardown"
        result = run_script(:teardown)
      end
      result
    end

    def self.get_num_scripts
      num_scripts = 0
      num_scripts += 1 if self.method_defined?(:setup)
      num_scripts += 1 if self.method_defined?(:teardown)
      num_scripts += self.scripts.length
      num_scripts
    end

    def self.puts(string)
      $stdout.puts string
      if @@current_result
        @@current_result.message ||= ''
        @@current_result.message << string.chomp
        @@current_result.message << "\n"
      end
    end

    def self.current_suite
      if @@current_result
        @@current_result.suite
      else
        nil
      end
    end

    def self.current_group
      if @@current_result
        @@current_result.group
      else
        nil
      end
    end

    def self.current_script
      if @@current_result
        @@current_result.script
      else
        nil
      end
    end
  end

  # Helper class to collect information about the running scripts like pass / fail counts
  class ScriptStatus
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

    def total=(new_total)
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
  end

  # Helper class to collect script result information
  class ScriptResult
    attr_accessor :suite
    attr_accessor :group
    attr_accessor :script
    attr_accessor :output
    attr_accessor :exceptions
    attr_accessor :stopped
    attr_accessor :result
    attr_accessor :message

    @@suite = nil

    def initialize
      @suite = nil
      @suite = @@suite.clone if @@suite
      @group = nil
      @script = nil
      @output = nil
      @exceptions = nil
      @stopped = false
      @result = :SKIP
      @message = nil
    end

    def self.suite=(suite)
      @@suite = suite
    end
  end
end
