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
    FUTURE_TIME = Time.new("2100")

    def initialize
      super()
      @name = "Limits Groups"
      @groups = get_limits_groups()
      # Initialize all the group names as instance variables. We don't need
      # them all but initialize them all just to be safe.
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
        # If the instance variable is not set it means the group isn't enabled
        # yet so print out a message and store the current time
        if not var
          Logger.info "Detected group #{group.upcase} enable condition"
          self.instance_variable_set(var_name, Time.now)
          # After setting the variable we need to get it again
          var = self.instance_variable_get(var_name)
        end
        # After the requested delay after power on we enable the group
        if Time.now > (var + delay)
          # Reset the instance variable to a distance future time so it won't satisfy
          # the above check but is also not nil which would trigger the first check
          self.instance_variable_set(var_name, FUTURE_TIME)
          @status = "Enabling group #{group.upcase} at #{Time.now}"
          Logger.info "Enabling group #{group.upcase}"
          enable_limits_group(group)
          # Call any additional enable code passed to the method
          enable_code.call if enable_code
        end
      else
        if var
          self.instance_variable_set(var_name, nil)
          @status = "Disabling group #{group.upcase} at #{Time.now}"
          Logger.info "Disabling group #{group.upcase}"
          disable_limits_group(group)
          # Call any additional disable code passed to the method
          disable_code.call if disable_code
        end
      end
    end

    def call
      Logger.info "Starting the LimitsGroupsBackgroundTask"
      check_methods = find_check_methods()
      # Initially disable all the groups as we assume everything is off
      @groups.each {|group| disable_limits_group(group) }
      sleep 5 # allow interfaces time to start
      loop do
        start = Time.now
        check_methods.each {|method| self.send(method.intern) }
        now = Time.now
        if (now - start) > 1.0
          Logger.warn "LimitsGroupsBackgroundTask took #{now - start} to process check methods"
          # No need to sleep because we're already over 1Hz. Just go back around.
        else
          sleep(1 - (now - start)) # Run the checks at 1Hz
        end
      end
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
