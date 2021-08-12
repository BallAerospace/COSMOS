# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'cosmos/script/suite'
require 'cosmos/script/suite_results'
require 'cosmos/tools/test_runner/test'

module Cosmos
  # Placeholder for all Groups discovered without assigned Suites
  class UnassignedSuite < Suite
  end

  class SuiteRunner
    @@suites = []
    @@settings = {}
    @@suite_results = nil

    def self.settings
      @@settings
    end

    def self.settings=(settings)
      @@settings = settings
    end

    def self.suite_results
      @@suite_results
    end

    def self.execute(result_string, suite_class, group_class = nil, script = nil)
      @@suite_results = SuiteResults.new
      @@suites.each do |suite|
        if suite.class == suite_class
          @@suite_results.start(result_string, suite_class, group_class, script, @@settings)
          loop do
            yield(suite)
            break if not @@settings['Loop'] or (ScriptStatus.instance.fail_count > 0 and @@settings['Break Loop On Error'])
          end
          break
        end
      end
    end

    def self.start(suite_class, group_class = nil, script = nil)
      result = []
      execute('', suite_class, group_class, script) do |suite|
        if script
          result = suite.run_script(group_class, script)
          @@suite_results.process_result(result)
          raise StopScript if (result.exceptions and Group.abort_on_exception) or result.stopped
        elsif group_class
          suite.run_group(group_class) { |current_result| @@suite_results.process_result(current_result); raise StopScript if current_result.stopped }
        else
          suite.run { |current_result| @@suite_results.process_result(current_result); raise StopScript if current_result.stopped }
        end
      end
    end

    def self.setup(suite_class, group_class = nil)
      execute('Manual Setup', suite_class, group_class) do |suite|
        if group_class
          result = suite.run_group_setup(group_class)
        else
          result = suite.run_setup
        end
        if result
          @@suite_results.process_result(result)
          raise StopScript if result.stopped
        end
      end
    end

    def self.teardown(suite_class, group_class = nil)
      execute('Manual Teardown', suite_class, group_class) do |suite|
        if group_class
          result = suite.run_group_teardown(group_class)
        else
          result = suite.run_teardown
        end
        if result
          @@suite_results.process_result(result)
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

    # Build list of Suites and Groups
    def self.build_suites
      @@suites = []
      # @@suites = @@suites.select { |my_suite| my_suite.name == 'CustomSuite' }
      suites = {}
      groups = []
      ObjectSpace.each_object(Class) do |object|
        # If we inherit from Suite but aren't the deprecated TestSuite
        if object < Suite && object != TestSuite
          # Ensure they didn't override name for some reason
          if object.instance_methods(false).include?(:name)
            raise FatalError.new("#{object} redefined the 'name' method. Delete the 'name' method and try again.")
          end

          # ObjectSpace.each_object appears to yield objects in the reverse
          # order that they were parsed by the interpreter so push each
          # Suite object to the front of the array to order as encountered
          @@suites.unshift(object.new)
        end
        # If we inherit from Group but aren't the deprecated Test
        if object < Group && object != Test
          # Ensure they didn't override self.name for some reason
          if object.methods(false).include?(:name)
            raise FatalError.new("#{object} redefined the 'self.name' method. Delete the 'self.name' method and try again.")
          end

          groups << object
        end
      end
      # Raise error if no suites or groups
      if @@suites.empty? || groups.empty?
        return "No Suite or no Group classes found"
      end

      # Create Suite for unassigned Groups
      @@suites.each do |suite|
        groups_to_delete = []
        groups.each { |group| groups_to_delete << group if suite.scripts[group] }
        groups_to_delete.each { |group| groups.delete(group) }
      end
      if groups.empty?
        @@suites = @@suites.select { |suite| suite.class != UnassignedSuite }
      else
        unassigned_suite = @@suites.select { |suite| suite.class == UnassignedSuite }[0]
        groups.each { |group| unassigned_suite.add_group(group) }
      end

      @@suites.each do |suite|
        cur_suite = OpenStruct.new(:setup => false, :teardown => false, :groups => {})
        cur_suite.setup = true if suite.class.method_defined?(:setup)
        cur_suite.teardown = true if suite.class.method_defined?(:teardown)

        suite.plans.each do |type, group_class, script|
          case type
          when :GROUP
            cur_suite.groups[group_class.name] ||=
              OpenStruct.new(:setup => false, :teardown => false, :scripts => [])
            cur_suite.groups[group_class.name].scripts.concat(group_class.scripts)
            cur_suite.groups[group_class.name].scripts.uniq!
            cur_suite.groups[group_class.name].setup = true if group_class.method_defined?(:setup)
            cur_suite.groups[group_class.name].teardown = true if group_class.method_defined?(:teardown)
          when :SCRIPT
            cur_suite.groups[group_class.name] ||=
              OpenStruct.new(:setup => false, :teardown => false, :scripts => [])
            # Explicitly check for this method and raise an error if it does not exist
            if group_class.method_defined?(script.intern)
              cur_suite.groups[group_class.name].scripts << script
              cur_suite.groups[group_class.name].scripts.uniq!
            else
              raise "#{group_class} does not have a #{script} method defined."
            end
            cur_suite.groups[group_class.name].setup = true if group_class.method_defined?(:setup)
            cur_suite.groups[group_class.name].teardown = true if group_class.method_defined?(:teardown)
          when :GROUP_SETUP
            cur_suite.groups[group_class.name] ||=
              OpenStruct.new(:setup => false, :teardown => false, :scripts => [])
            # Explicitly check for the setup method and raise an error if it does not exist
            if group_class.method_defined?(:setup)
              cur_suite.groups[group_class.name].setup = true
            else
              raise "#{group_class} does not have a setup method defined."
            end
          when :GROUP_TEARDOWN
            cur_suite.groups[group_class.name] ||=
              OpenStruct.new(:setup => false, :teardown => false, :scripts => [])
            # Explicitly check for the teardown method and raise an error if it does not exist
            if group_class.method_defined?(:teardown)
              cur_suite.groups[group_class.name].teardown = true
            else
              raise "#{group_class} does not have a teardown method defined."
            end
          end
        end
        suites[suite.name.split('::')[-1]] = open_struct_to_hash(cur_suite) unless suite.name == 'CustomSuite'
      end
      return suites
    end
  end
end
