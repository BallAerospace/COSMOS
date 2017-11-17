# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/cmd_tlm_server/background_task'

module Cosmos
  # Monitors telemetry and enables and disables limits groups
  class LimitsGroupsBackgroundTask < BackgroundTask
    attr_reader :groups
    # Time in the future that we will never hit to allow the logic to work
    FUTURE_TIME = Time.new("3000")
    PAST_TIME = Time.new("1900")

    def initialize(initial_delay = 0, task_delay = 0.5)
      super()
      @initial_delay = Float(initial_delay)
      @task_delay = Float(task_delay)
      @name = "Limits Groups"
      @groups = get_limits_groups()
      @sleeper = Sleeper.new
      # Initialize all the group names as instance variables
      @groups.each {|group| self.instance_variable_set("@#{group.downcase}", nil) }
    end

    # Enables and disables COSMOS limits groups. The group named after the
    # passed group variable is automatically enabled and disabled when the
    # yielded to block returns true and false respectively. In addition, any
    # groups with the same name and a _PRI or _RED extension are also enabled
    # or disabled with the base group.
    #
    # @param delay [Integer] The amount of time to wait after detecting the group
    #   power on condition before actually enabling the group. A delay
    #   allows time for telemetry to stability to avoid false positives.
    # @param enable_code [Proc] Code to execute when the group is enabled
    # @param disable_code [Proc] Code to execute when the group is disabled
    def process_group(delay = 0, enable_code = nil, disable_code = nil)
      group = calling_method.to_s[6..-1]

      # Grab the instance variable based on the group name
      var_name = "@#{group}"
      var = self.instance_variable_get(var_name)
      # Yield to the block to perform the telemetry check
      if yield
        # If the instance variable is not set or set in the past
        # (by the disable logic) it means the group isn't enabled
        # so store the current time to allow for an enable delay
        if !var || var == PAST_TIME
          self.instance_variable_set(var_name, Time.now)
          # After setting the variable we need to get it again
          var = self.instance_variable_get(var_name)
        end
        # After the requested delay after power on we enable the group
        if Time.now > (var + delay)
          # Reset the instance variable to a distance future time
          # so it won't satisfy any of the other checks and enable the group
          self.instance_variable_set(var_name, FUTURE_TIME)
          enable_limits_group(group)
          # Call any additional enable code passed to the method
          enable_code.call if enable_code
        end
      else
        # If the instance variable is not set or set in the future
        # (by the enable logic) it means the group isn't disabled
        # Reset the instance variable to a distance past time so it
        # won't satisfy any of the other checks and disable the group
        if !var || var == FUTURE_TIME
          self.instance_variable_set(var_name, PAST_TIME)
          disable_limits_group(group)
          # Call any additional disable code passed to the method
          disable_code.call if disable_code
        end
      end
    end

    def call
      @status = "Starting the LimitsGroupsBackgroundTask"
      @sleeper = Sleeper.new
      check_methods = find_check_methods()
      return if @sleeper.sleep(@initial_delay)
      loop do
        start = Time.now
        check_methods.each {|method| self.send(method.intern) }
        now = Time.now
        @status = "#{now.formatted}: Checking groups took #{now - start}s"
        sleep_time = @task_delay - (now - start)
        sleep_time = 0 if sleep_time < 0
        return if @sleeper.sleep(sleep_time)
      end
    end

    def stop
      @sleeper.cancel
      @status = "Stopped at #{Time.now.sys.formatted}"
    end

    protected

    def find_check_methods
      # Find all the check methods (begins with 'check_')
      check_methods = []
      self.class.instance_methods.each do |method_name|
        if method_name.to_s =~ /^check_/
          # The second part of the method must correspond to a group name
          if @groups.include?(method_name.to_s[6..-1].upcase)
            check_methods << method_name.to_s
          else
            raise "Method #{method_name} doesn't match a group name.\n"\
              "Methods must begin with 'check_' and end with a valid group name.\n"\
              "Groups are #{@groups.join(', ')}."
          end
        end
      end
      check_methods.sort # Sort by name
    end
  end
end
