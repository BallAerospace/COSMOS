require 'cosmos/script'
require 'cosmos/tools/test_runner/test'

module Cosmos
  # Placeholder for all tests discovered without assigned TestSuites
  class UnassignedTestSuite < TestSuite
  end

  class TestRunner
    @@test_suites = []
    @@settings = {}

    def self.exec_test(result_string, test_suite_class, test_class = nil, test_case = nil)
      @@started_success = false
      @@test_suites.each do |test_suite|
        if test_suite.class == test_suite_class
          # @@started_success = @@results_writer.collect_metadata(@@instance)
          # if @@started_success
            # @@results_writer.start(result_string, test_suite_class, test_class, test_case, @@settings)
            # loop do
              yield(test_suite)
              # break if not @@settings['Loop Testing'] or (TestStatus.instance.fail_count > 0 and @@settings['Break Loop after Error'])
            # end
          # end
          break
        end
      end
    end

    def self.start(test_suite_class, test_class = nil, test_case = nil)
      result = []
      exec_test('', test_suite_class, test_class, test_case) do |test_suite|
        if test_case
          result = test_suite.run_test_case(test_class, test_case)
          # @@results_writer.process_result(result)
          raise StopScript if (result.exceptions and Test.abort_on_exception) or result.stopped
        # elsif test_class
        #   test_suite.run_test(test_class) { |current_result| @@results_writer.process_result(current_result); raise StopScript if current_result.stopped }
        # else
        #   test_suite.run { |current_result| @@results_writer.process_result(current_result); raise StopScript if current_result.stopped }
        end
      end
    end

    def self.start_setup(test_suite_class, test_class = nil)
      exec_test('Manual Setup', test_suite_class, test_class) do |test_suite|
        if test_class
          result = test_suite.run_test_setup(test_class)
        else
          result = test_suite.run_setup
        end
        if result
          # @@results_writer.process_result(result)
          raise StopScript if result.stopped
        end
      end
    end

    def self.start_teardown(test_suite_class, test_class = nil)
      exec_test('Manual Teardown', test_suite_class, test_class) do |test_suite|
        if test_class
          result = test_suite.run_test_teardown(test_class)
        else
          result = test_suite.run_teardown
        end
        if result
          # @@results_writer.process_result(result)
          raise StopScript if result.stopped
        end
      end
    end

    # Convert the OpenStruct structure to a simple hash
    # TODO: Maybe just use hashes right from the beginning?
    def self.open_struct_to_hash(object)
      hash = object.to_h
      hash.each do |key1, val1|
        if val1.is_a?(Hash)
          val1.each do |key2, val2|
            if val2.is_a?(OpenStruct)
              hash[key1][key2] = val2.to_h
            end
          end
        end
      end
      hash
    end

    def self.build_test_suites
      suites = {}
      ignored_test_classes = []
      ignored_test_suite_classes = []

      # @ignore_tests.each do |test_name|
      #   begin
      #     klass = Object.const_get(test_name)
      #     ignored_test_classes << klass if klass
      #   rescue
      #   end
      # end

      # @ignore_test_suites.each do |test_suite_name|
      #   begin
      #     klass = Object.const_get(test_suite_name)
      #     ignored_test_suite_classes << klass if klass
      #   rescue
      #   end
      # end

      # Build list of TestSuites and Tests
      @@test_suites = @@test_suites.select {|my_suite| my_suite.name == 'CustomTestSuite'}
      tests = []
      ObjectSpace.each_object(Class) do |object|
        begin
          next if object.name == 'CustomTestSuite'
          ancestors = object.ancestors
        rescue
          # Ignore Classes where name or ancestors may raise exception
          # Bundler::Molinillo::DependencyGraph::Action is one example
          next
        end
        if (ancestors.include?(TestSuite) &&
            object != TestSuite &&
            !ignored_test_suite_classes.include?(object))
          # Ensure they didn't override name for some reason
          if object.instance_methods(false).include?(:name)
            raise FatalError.new("#{object} redefined the 'name' method. Delete the 'name' method and try again.")
          end
          # ObjectSpace.each_object appears to yield objects in the reverse
          # order that they were parsed by the interpreter so push each
          # TestSuite object to the front of the array to order as encountered
          @@test_suites.unshift(object.new)
        end
        if (ancestors.include?(Test) &&
            object != Test &&
            !ignored_test_classes.include?(object))
          # Ensure they didn't override self.name for some reason
          if object.methods(false).include?(:name)
            raise FatalError.new("#{object} redefined the 'self.name' method. Delete the 'self.name' method and try again.")
          end
          tests << object
        end
      end
      # Raise error if no test suites or tests
      if @@test_suites.empty? || tests.empty?
        msg = "No TestSuites or no Test classes found"
        if !ignored_test_suite_classes.empty?
          msg << "\n\nThe following TestSuites were found but ignored:\n#{ignored_test_suite_classes.join(", ")}"
        end
        if !ignored_test_classes.empty?
          msg << "\n\nThe following Tests were found but ignored:\n#{ignored_test_classes.join(", ")}"
        end
        return msg
      end

      # Create TestSuite for unassigned Tests
      @@test_suites.each do |test_suite|
        tests_to_delete = []
        tests.each { |test| tests_to_delete << test if test_suite.tests[test] }
        tests_to_delete.each { |test| tests.delete(test) }
      end
      if tests.empty?
        @@test_suites = @@test_suites.select {|suite| suite.class != UnassignedTestSuite}
      else
        uts = @@test_suites.select {|suite| suite.class == UnassignedTestSuite}[0]
        tests.each { |test| uts.add_test(test) }
      end

      @@test_suites.each do |suite|
        cur_suite = OpenStruct.new(:setup=>false, :teardown=>false, :tests=>{})
        cur_suite.setup = true if suite.class.method_defined?(:setup)
        cur_suite.teardown = true if suite.class.method_defined?(:teardown)

        suite.plans.each do |test_type, test_class, test_case|
          case test_type
          when :TEST
            cur_suite.tests[test_class.name] ||=
              OpenStruct.new(:setup=>false, :teardown=>false, :cases=>[])
            cur_suite.tests[test_class.name].cases.concat(test_class.test_cases)
            cur_suite.tests[test_class.name].cases.uniq!
            cur_suite.tests[test_class.name].setup = true if test_class.method_defined?(:setup)
            cur_suite.tests[test_class.name].teardown = true if test_class.method_defined?(:teardown)
          when :TEST_CASE
            cur_suite.tests[test_class.name] ||=
              OpenStruct.new(:setup=>false, :teardown=>false, :cases=>[])
            # Explicitly check for this method and raise an error if it does not exist
            if test_class.method_defined?(test_case.intern)
              cur_suite.tests[test_class.name].cases << test_case
              cur_suite.tests[test_class.name].cases.uniq!
            else
              raise "#{test_class} does not have a #{test_case} method defined."
            end
            cur_suite.tests[test_class.name].setup = true if test_class.method_defined?(:setup)
            cur_suite.tests[test_class.name].teardown = true if test_class.method_defined?(:teardown)
          when :TEST_SETUP
            cur_suite.tests[test_class.name] ||=
              OpenStruct.new(:setup=>false, :teardown=>false, :cases=>[])
            # Explicitly check for the setup method and raise an error if it does not exist
            if test_class.method_defined?(:setup)
              cur_suite.tests[test_class.name].setup = true
            else
              raise "#{test_class} does not have a setup method defined."
            end
          when :TEST_TEARDOWN
            cur_suite.tests[test_class.name] ||=
              OpenStruct.new(:setup=>false, :teardown=>false, :cases=>[])
            # Explicitly check for the teardown method and raise an error if it does not exist
            if test_class.method_defined?(:teardown)
              cur_suite.tests[test_class.name].teardown = true
            else
              raise "#{test_class} does not have a teardown method defined."
            end
          end
        end
        suites[suite.name.split('::')[-1]] = open_struct_to_hash(cur_suite) unless suite.name == 'CustomTestSuite'
      end
      return suites
    end
  end
end
