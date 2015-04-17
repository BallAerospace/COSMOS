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
    def _log_cmd(target_name, cmd_name, cmd_params, raw, range, hazardous)
      if range
        Logger.warn "Command #{target_name} #{cmd_name} being sent ignoring range checks"
      end
      if hazardous
        Logger.warn "Command #{target_name} #{cmd_name} being sent ignoring hazardous warnings"
      end
      Logger.info build_cmd_output_string(target_name, cmd_name, cmd_params, raw)
    end

    # Send a command to the specified target
    # Usage:
    #   cmd(target_name, cmd_name, cmd_params = {})
    # or
    #   cmd('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd(*args)
      begin
        target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd(*args)
        _log_cmd(target_name, cmd_name, cmd_params, false, false, false)
      rescue HazardousError => e
        ok_to_proceed = prompt_for_hazardous(e.target_name,
                                             e.cmd_name,
                                             e.hazardous_description)
        if ok_to_proceed
          target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd_no_hazardous_check(*args)
          _log_cmd(target_name, cmd_name, cmd_params, false, false, false)
        else
          retry unless prompt_for_script_abort()
        end
      end
    end

    # Send a command to the specified target without range checking parameters
    # Usage:
    #   cmd_no_range_check(target_name, cmd_name, cmd_params = {})
    # or
    #   cmd_no_range_check('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd_no_range_check(*args)
      begin
        target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd_no_range_check(*args)
        _log_cmd(target_name, cmd_name, cmd_params, false, true, false)
      rescue HazardousError => e
        ok_to_proceed = prompt_for_hazardous(e.target_name,
                                             e.cmd_name,
                                             e.hazardous_description)
        if ok_to_proceed
          target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd_no_checks(*args)
          _log_cmd(target_name, cmd_name, cmd_params, false, true, false)
        else
          retry unless prompt_for_script_abort()
        end
      end
    end

    # Send a command to the specified target without hazardous checks
    # Usage:
    #   cmd_no_hazardous_check(target_name, cmd_name, cmd_params = {})
    # or
    #   cmd_no_hazardous_check('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd_no_hazardous_check(*args)
      target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd_no_hazardous_check(*args)
      _log_cmd(target_name, cmd_name, cmd_params, false, false, true)
    end

    # Send a command to the specified target without range checking or hazardous checks
    # Usage:
    #   cmd_no_checks(target_name, cmd_name, cmd_params = {})
    # or
    #   cmd_no_checks('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd_no_checks(*args)
      target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd_no_checks(*args)
      _log_cmd(target_name, cmd_name, cmd_params, false, true, true)
    end

    # Send a command to the specified target without running conversions
    # Usage:
    #   cmd_raw(target_name, cmd_name, cmd_params = {})
    # or
    #   cmd_raw('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd_raw(*args)
      begin
        target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd_raw(*args)
        _log_cmd(target_name, cmd_name, cmd_params, true, false, false)
      rescue HazardousError => e
        ok_to_proceed = prompt_for_hazardous(e.target_name,
                                             e.cmd_name,
                                             e.hazardous_description)
        if ok_to_proceed
          target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd_raw_no_hazardous_check(*args)
          _log_cmd(target_name, cmd_name, cmd_params, true, false, false)
        else
          retry unless prompt_for_script_abort()
        end
      end
    end

    # Send a command to the specified target without range checking parameters or running conversions
    # Usage:
    #   cmd_raw_no_range_check(target_name, cmd_name, cmd_params = {})
    # or
    #   cmd_raw_no_range_check('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd_raw_no_range_check(*args)
      begin
        target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd_raw_no_range_check(*args)
        _log_cmd(target_name, cmd_name, cmd_params, true, true, false)
      rescue HazardousError => e
        ok_to_proceed = prompt_for_hazardous(e.target_name,
                                             e.cmd_name,
                                             e.hazardous_description)
        if ok_to_proceed
          target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd_raw_no_checks(*args)
          _log_cmd(target_name, cmd_name, cmd_params, true, true, false)
        else
          retry unless prompt_for_script_abort()
        end
      end
    end

    # Send a command to the specified target without hazardous checks or running conversions
    # Usage:
    #   cmd_raw_no_hazardous_check(target_name, cmd_name, cmd_params = {})
    # or
    #   cmd_raw_no_hazardous_check('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd_raw_no_hazardous_check(*args)
      target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd_raw_no_hazardous_check(*args)
      _log_cmd(target_name, cmd_name, cmd_params, true, false, true)
    end

    # Send a command to the specified target without range checking or hazardous checks or running conversions
    # Usage:
    #   cmd_raw_no_checks(target_name, cmd_name, cmd_params = {})
    # or
    #   cmd_raw_no_checks('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd_raw_no_checks(*args)
      target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd_raw_no_checks(*args)
      _log_cmd(target_name, cmd_name, cmd_params, true, true, true)
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

    def get_cmd_list(target_name)
      return $cmd_tlm_server.get_cmd_list(target_name)
    end

    def get_cmd_param_list(target_name, cmd_name)
      return $cmd_tlm_server.get_cmd_param_list(target_name, cmd_name)
    end

    def get_cmd_hazardous(target_name, cmd_name, cmd_params = {})
      return $cmd_tlm_server.get_cmd_hazardous(target_name, cmd_name, cmd_params)
    end

  end
end

