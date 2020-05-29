# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos
  module Script
    private

    # Log any warnings about disabling checks and log the command itself
    # NOTE: This is a helper method and should not be called directly
    def _log_cmd(target_name, cmd_name, cmd_params, raw, no_range, no_hazardous)
      if no_range
        Logger.warn "Command #{target_name} #{cmd_name} being sent ignoring range checks"
      end
      if no_hazardous
        Logger.warn "Command #{target_name} #{cmd_name} being sent ignoring hazardous warnings"
      end
      # TODO; Logger.info System.commands.build_cmd_output_string(target_name, cmd_name, cmd_params, raw)
    end

    # Send the command and log the results
    # NOTE: This is a helper method and should not be called directly
    def _cmd(cmd, cmd_no_hazardous, *args)
      raw = cmd.include?('raw')
      no_range = cmd.include?('no_range') || cmd.include?('no_checks')
      no_hazardous = cmd.include?('no_hazardous') || cmd.include?('no_checks')

      begin
        target_name, cmd_name, cmd_params = $cmd_tlm_server.method_missing(cmd, *args)
        _log_cmd(target_name, cmd_name, cmd_params, raw, no_range, no_hazardous)
      rescue HazardousError => e
        ok_to_proceed = prompt_for_hazardous(e.target_name,
                                             e.cmd_name,
                                             e.hazardous_description)
        if ok_to_proceed
          target_name, cmd_name, cmd_params = $cmd_tlm_server.method_missing(cmd_no_hazardous, *args)
          _log_cmd(target_name, cmd_name, cmd_params, raw, no_range, no_hazardous)
        else
          retry unless prompt_for_script_abort()
        end
      end
    end

    # Send a command to the specified target
    # Usage:
    #   cmd(target_name, cmd_name, cmd_params = {})
    # or
    #   cmd('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd(*args)
      _cmd('cmd', 'cmd_no_hazardous_check', *args)
    end

    # Send a command to the specified target without range checking parameters
    # Usage:
    #   cmd_no_range_check(target_name, cmd_name, cmd_params = {})
    # or
    #   cmd_no_range_check('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd_no_range_check(*args)
      _cmd('cmd_no_range_check', 'cmd_no_checks', *args)
    end

    # Send a command to the specified target without hazardous checks
    # Usage:
    #   cmd_no_hazardous_check(target_name, cmd_name, cmd_params = {})
    # or
    #   cmd_no_hazardous_check('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd_no_hazardous_check(*args)
      _cmd('cmd_no_hazardous_check', nil, *args)
    end

    # Send a command to the specified target without range checking or hazardous checks
    # Usage:
    #   cmd_no_checks(target_name, cmd_name, cmd_params = {})
    # or
    #   cmd_no_checks('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd_no_checks(*args)
      _cmd('cmd_no_checks', nil, *args)
    end

    # Send a command to the specified target without running conversions
    # Usage:
    #   cmd_raw(target_name, cmd_name, cmd_params = {})
    # or
    #   cmd_raw('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd_raw(*args)
      _cmd('cmd_raw', 'cmd_raw_no_hazardous_check', *args)
    end

    # Send a command to the specified target without range checking parameters or running conversions
    # Usage:
    #   cmd_raw_no_range_check(target_name, cmd_name, cmd_params = {})
    # or
    #   cmd_raw_no_range_check('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd_raw_no_range_check(*args)
      _cmd('cmd_raw_no_range_check', 'cmd_raw_no_checks', *args)
    end

    # Send a command to the specified target without hazardous checks or running conversions
    # Usage:
    #   cmd_raw_no_hazardous_check(target_name, cmd_name, cmd_params = {})
    # or
    #   cmd_raw_no_hazardous_check('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd_raw_no_hazardous_check(*args)
      _cmd('cmd_raw_no_hazardous_check', nil, *args)
    end

    # Send a command to the specified target without range checking or hazardous checks or running conversions
    # Usage:
    #   cmd_raw_no_checks(target_name, cmd_name, cmd_params = {})
    # or
    #   cmd_raw_no_checks('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd_raw_no_checks(*args)
      _cmd('cmd_raw_no_checks', nil, *args)
    end

    # Sends raw data through an interface
    def send_raw(interface_name, data)
      return $cmd_tlm_server.send_raw(interface_name, data)
    end

    # Sends raw data through an interface from a file
    def send_raw_file(interface_name, filename)
      data = nil
      File.open(filename, 'rb') {|file| data = file.read}
      return $cmd_tlm_server.send_raw(interface_name, data)
    end

    # Returns all the target commands as an array of arrays listing the command
    # name and description.
    def get_cmd_list(target_name)
      return $cmd_tlm_server.get_cmd_list(target_name)
    end

    # Returns all the parameters for given command as an array of arrays
    # containing the parameter name, default value, states, description, units
    # full name, units abbreviation, and whether it is required.
    def get_cmd_param_list(target_name, cmd_name)
      return $cmd_tlm_server.get_cmd_param_list(target_name, cmd_name)
    end

    # Returns whether a command is hazardous (true or false)
    def get_cmd_hazardous(target_name, cmd_name, cmd_params = {})
      return $cmd_tlm_server.get_cmd_hazardous(target_name, cmd_name, cmd_params)
    end

    # Returns a value from the specified command
    def get_cmd_value(target_name, command_name, parameter_name, value_type = :CONVERTED)
      return $cmd_tlm_server.get_cmd_value(target_name, command_name, parameter_name, value_type)
    end

    # Returns the time the most recent command was sent
    def get_cmd_time(target_name = nil, command_name = nil)
      results = $cmd_tlm_server.get_cmd_time(target_name, command_name)
      if Array === results
        if results[2] and results[3]
          results[2] = Time.at(results[2], results[3]).sys
        end
        results.delete_at(3)
      end
      results
    end

    # Returns the buffer from the most recent specified command
    def get_cmd_buffer(target_name, command_name)
      return $cmd_tlm_server.get_cmd_buffer(target_name, command_name)
    end

  end # module Script

end # module Cosmos
