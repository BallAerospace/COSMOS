# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/io/json_drb_object'
require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server'
require 'cosmos/script/extract'

$cmd_tlm_server = nil
$cmd_tlm_disconnect = false

module Cosmos
  class CheckError < RuntimeError; end
  class StopScript < StandardError; end
  class SkipTestCase < StandardError; end

  module Script
    DEFAULT_TLM_POLLING_RATE = 0.25

    private

    include Extract

    #######################################
    # Methods accessing cmd_tlm_server
    #######################################

    #
    # Methods involving commands
    #

    # Send a command to the specified target
    # Supports two signatures:
    # cmd(target_name, cmd_name, cmd_params = {})
    # or
    # cmd('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd(*args)
      begin
        target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd(*args)
        Logger.info build_cmd_output_string(target_name, cmd_name, cmd_params)
      rescue HazardousError => e
        ok_to_proceed = prompt_for_hazardous(e.target_name,
                                             e.cmd_name,
                                             e.hazardous_description)
        if ok_to_proceed
          target_name, cmd_name, cmd_params =
            $cmd_tlm_server.cmd_no_hazardous_check(*args)
          Logger.info build_cmd_output_string(target_name, cmd_name, cmd_params)
        else
          retry unless prompt_for_script_abort()
        end
      end
    end

    # Send a command to the specified target without range checking parameters
    # Supports two signatures:
    # cmd_no_range_check(target_name, cmd_name, cmd_params = {})
    # or
    # cmd_no_range_check('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd_no_range_check(*args)
      begin
        target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd_no_range_check(*args)
        Logger.warn "Command #{target_name} #{cmd_name} being sent ignoring range checks"
        Logger.info build_cmd_output_string(target_name, cmd_name, cmd_params)
      rescue HazardousError => e
        ok_to_proceed = prompt_for_hazardous(e.target_name,
                                             e.cmd_name,
                                             e.hazardous_description)
        if ok_to_proceed
          target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd_no_checks(*args)
          Logger.warn "Command #{target_name} #{cmd_name} being sent ignoring range checks"
          Logger.info build_cmd_output_string(target_name, cmd_name, cmd_params)
        else
          retry unless prompt_for_script_abort()
        end
      end
    end

    # Send a command to the specified target without hazardous checks
    # Supports two signatures:
    # cmd_no_hazardous_check(target_name, cmd_name, cmd_params = {})
    # or
    # cmd_no_hazardous_check('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd_no_hazardous_check(*args)
      target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd_no_hazardous_check(*args)
      Logger.warn "Command #{target_name} #{cmd_name} being sent ignoring hazardous warnings"
      Logger.info build_cmd_output_string(target_name, cmd_name, cmd_params)
    end

    # Send a command to the specified target without range checking or hazardous checks
    # Supports two signatures:
    # cmd_no_checks(target_name, cmd_name, cmd_params = {})
    # or
    # cmd_no_checks('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd_no_checks(*args)
      target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd_no_checks(*args)
      Logger.warn "Command #{target_name} #{cmd_name} being sent ignoring range checks"
      Logger.warn "Command #{target_name} #{cmd_name} being sent ignoring hazardous warnings"
      Logger.info build_cmd_output_string(target_name, cmd_name, cmd_params)
    end

    # Send a command to the specified target without running conversions
    # Supports two signatures:
    # cmd_raw(target_name, cmd_name, cmd_params = {})
    # or
    # cmd_raw('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd_raw(*args)
      begin
        target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd_raw(*args)
        Logger.info build_cmd_output_string(target_name, cmd_name, cmd_params, true)
      rescue HazardousError => e
        ok_to_proceed = prompt_for_hazardous(e.target_name,
                                             e.cmd_name,
                                             e.hazardous_description)
        if ok_to_proceed
          target_name, cmd_name, cmd_params =
            $cmd_tlm_server.cmd_raw_no_hazardous_check(*args)
          Logger.info build_cmd_output_string(target_name, cmd_name, cmd_params, true)
        else
          retry unless prompt_for_script_abort()
        end
      end
    end

    # Send a command to the specified target without range checking parameters or running conversions
    # Supports two signatures:
    # cmd_raw_no_range_check(target_name, cmd_name, cmd_params = {})
    # or
    # cmd_raw_no_range_check('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd_raw_no_range_check(*args)
      begin
        target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd_raw_no_range_check(*args)
        Logger.warn "Command #{target_name} #{cmd_name} being sent ignoring range checks"
        Logger.info build_cmd_output_string(target_name, cmd_name, cmd_params, true)
      rescue HazardousError => e
        ok_to_proceed = prompt_for_hazardous(e.target_name,
                                             e.cmd_name,
                                             e.hazardous_description)
        if ok_to_proceed
          target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd_raw_no_checks(*args)
          Logger.warn "Command #{target_name} #{cmd_name} being sent ignoring range checks"
          Logger.info build_cmd_output_string(target_name, cmd_name, cmd_params, true)
        else
          retry unless prompt_for_script_abort()
        end
      end
    end

    # Send a command to the specified target without hazardous checks or running conversions
    # Supports two signatures:
    # cmd_raw_no_hazardous_check(target_name, cmd_name, cmd_params = {})
    # or
    # cmd_raw_no_hazardous_check('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd_raw_no_hazardous_check(*args)
      target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd_raw_no_hazardous_check(*args)
      Logger.warn "Command #{target_name} #{cmd_name} being sent ignoring hazardous warnings"
      Logger.info build_cmd_output_string(target_name, cmd_name, cmd_params, true)
    end

    # Send a command to the specified target without range checking or hazardous checks or running conversions
    # Supports two signatures:
    # cmd_raw_no_checks(target_name, cmd_name, cmd_params = {})
    # or
    # cmd_raw_no_checks('target_name cmd_name with cmd_param1 value1, cmd_param2 value2')
    def cmd_raw_no_checks(*args)
      target_name, cmd_name, cmd_params = $cmd_tlm_server.cmd_raw_no_checks(*args)
      Logger.warn "Command #{target_name} #{cmd_name} being sent ignoring range checks"
      Logger.warn "Command #{target_name} #{cmd_name} being sent ignoring hazardous warnings"
      Logger.info build_cmd_output_string(target_name, cmd_name, cmd_params, true)
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

    #
    # Methods involving telemetry
    #

    # Poll for the converted value of a telemetry item
    # Supports two signatures:
    # tlm(target_name, packet_name, item_name)
    # or
    # tlm('target_name packet_name item_name')
    def tlm(*args)
      return $cmd_tlm_server.tlm(*args)
    end

    # Poll for the raw value of a telemetry item
    # Supports two signatures:
    # tlm_raw(target_name, packet_name, item_name)
    # or
    # tlm_raw('target_name packet_name item_name')
    def tlm_raw(*args)
      return $cmd_tlm_server.tlm_raw(*args)
    end

    # Poll for the formatted value of a telemetry item
    # Supports two signatures:
    # tlm_formatted(target_name, packet_name, item_name)
    # or
    # tlm_formatted('target_name packet_name item_name')
    def tlm_formatted(*args)
      return $cmd_tlm_server.tlm_formatted(*args)
    end

    # Poll for the formatted with units value of a telemetry item
    # Supports two signatures:
    # tlm_with_units(target_name, packet_name, item_name)
    # or
    # tlm_with_units('target_name packet_name item_name')
    def tlm_with_units(*args)
      return $cmd_tlm_server.tlm_with_units(*args)
    end

    def tlm_variable(*args)
      return $cmd_tlm_server.tlm_variable(*args)
    end

    # Set a telemetry point
    def set_tlm(*args)
      return $cmd_tlm_server.set_tlm(*args)
    end

    # Set the raw value of a telemetry point
    def set_tlm_raw(*args)
      return $cmd_tlm_server.set_tlm_raw(*args)
    end

    def get_tlm_packet(target_name, packet_name, value_types = :CONVERTED)
      result = $cmd_tlm_server.get_tlm_packet(target_name, packet_name, value_types)
      result.each do |entry|
        entry[2] = entry[2].to_s.intern if entry[2]
      end
      result
    end

    def get_tlm_values(items, value_types = :CONVERTED)
      result = $cmd_tlm_server.get_tlm_values(items, value_types)
      result[1].length.times do |index|
        result[1][index] = result[1][index].to_s.intern if result[1][index]
      end
      result[3] = result[3].to_s.intern
      result
    end

    def get_tlm_list(target_name)
      return $cmd_tlm_server.get_tlm_list(target_name)
    end

    def get_tlm_item_list(target_name, packet_name)
      return $cmd_tlm_server.get_tlm_item_list(target_name, packet_name)
    end

    def get_tlm_details(items)
      $cmd_tlm_server.get_tlm_details(items)
    end

    def get_out_of_limits
      result = $cmd_tlm_server.get_out_of_limits
      result.each do |entry|
        entry[3] = entry[3].to_s.intern if entry[3]
      end
      result
    end

    def get_overall_limits_state (ignored_items = nil)
      return $cmd_tlm_server.get_overall_limits_state(ignored_items).to_s.intern
    end

    def limits_enabled?(*args)
      return $cmd_tlm_server.limits_enabled?(*args)
    end

    def enable_limits(*args)
      return $cmd_tlm_server.enable_limits(*args)
    end

    def disable_limits(*args)
      return $cmd_tlm_server.disable_limits(*args)
    end

    def get_limits(target_name, packet_name, item_name, limits_set = nil)
      results = $cmd_tlm_server.get_limits(target_name, packet_name, item_name, limits_set)
      results[0] = results[0].to_s.intern if results[0]
      return results
    end

    def set_limits(target_name, packet_name, item_name, red_low, yellow_low, yellow_high, red_high, green_low = nil, green_high = nil, limits_set = :CUSTOM, persistence = nil, enabled = true)
      results = $cmd_tlm_server.set_limits(target_name, packet_name, item_name, red_low, yellow_low, yellow_high, red_high, green_low, green_high, limits_set, persistence, enabled)
      results[0] = results[0].to_s.intern if results[0]
      return results
    end

    def get_limits_groups
      return $cmd_tlm_server.get_limits_groups
    end

    def enable_limits_group(group_name)
      return $cmd_tlm_server.enable_limits_group(group_name)
    end

    def disable_limits_group(group_name)
      return $cmd_tlm_server.disable_limits_group(group_name)
    end

    def get_limits_sets
      result = $cmd_tlm_server.get_limits_sets
      result.each_with_index do |limits_set, index|
        result[index] = limits_set.to_s.intern
      end
      return result
    end

    def set_limits_set(limits_set)
      return $cmd_tlm_server.set_limits_set(limits_set)
    end

    def get_limits_set
      result = $cmd_tlm_server.get_limits_set
      # Limits sets are always represented as symbols
      result.to_s.intern
    end

    #
    # General Purpose Methods
    #

    def get_target_list
      return $cmd_tlm_server.get_target_list
    end

    def subscribe_limits_events(queue_size = CmdTlmServer::DEFAULT_LIMITS_EVENT_QUEUE_SIZE)
      return $cmd_tlm_server.subscribe_limits_events(queue_size)
    end

    def unsubscribe_limits_events(id)
      return $cmd_tlm_server.unsubscribe_limits_events(id)
    end

    def get_limits_event(id, non_block = false)
      result = $cmd_tlm_server.get_limits_event(id, non_block)
      if result
        result[0] = result[0].to_s.intern
        if result[0] == :LIMITS_CHANGE
          result[1][3] = result[1][3].to_s.intern if result[1][3]
          result[1][4] = result[1][4].to_s.intern if result[1][4]
        elsif result[0] == :LIMITS_SETTINGS
          result[1][3] = result[1][3].to_s.intern if result[1][3]
        else
          result[1] = result[1].to_s.intern
        end
      end
      result
    end

    def subscribe_packet_data(packets, queue_size = CmdTlmServer::DEFAULT_PACKET_DATA_QUEUE_SIZE)
      result = $cmd_tlm_server.subscribe_packet_data(packets, queue_size)
      result
    end

    def unsubscribe_packet_data(id)
      result = $cmd_tlm_server.unsubscribe_packet_data(id)
      result
    end

    def get_packet_data(id, non_block = false)
      results = $cmd_tlm_server.get_packet_data(id, non_block)
      if Array === results and results[3] and results[4]
        results[3] = Time.at(results[3], results[4])
        results.delete_at(4)
      end
      results
    end

    def get_packet(id, non_block = false)
      packet = nil
      buffer, target_name, packet_name, received_time, received_count = get_packet_data(id, non_block)
      if buffer
        packet = System.telemetry.packet(target_name, packet_name).clone
        packet.buffer = buffer
        packet.received_time = received_time
        packet.received_count = received_count
      end
      packet
    end

    #
    # Methods for scripting
    #

    def play_wav_file(wav_filename)
      if defined? Qt
        Qt.execute_in_main_thread(true) do
          if Qt::CoreApplication.instance and Qt::Sound.isAvailable
            Cosmos.set_working_dir do
              Qt::Sound.play(wav_filename.to_s)
            end
          end
        end
      end
    end

    def status_bar(message)
      script_runner = nil
      ObjectSpace.each_object {|object| if ScriptRunner === object then script_runner = object; break; end}
      script_runner.script_set_status(message) if script_runner
    end

    def ask_string(question, blank_or_default = false, password = false)
      answer = ''
      default = ''
      if blank_or_default != true && blank_or_default != false
        question << " (default = #{blank_or_default})"
        allow_blank = true
      else
        allow_blank = blank_or_default
      end
      while answer.empty?
        print question + " "
        answer = gets
        answer.chomp!
        break if allow_blank
      end
      answer = default if answer.empty? and !default.empty?
      return answer
    end

    def ask(question, blank_or_default = false, password = false)
      string = ask_string(question, blank_or_default, password)
      value = string.convert_to_value
      return value
    end

    def prompt(string)
      prompt_to_continue(string)
    end

    def message_box(string, *buttons)
      prompt_message_box(string, buttons)
    end

    def _check(*args)
      target_name, packet_name, item_name, comparison_to_eval =
        check_process_args(args, 'check')
      value = yield(target_name, packet_name, item_name)
      if comparison_to_eval
        check_eval(target_name, packet_name, item_name, comparison_to_eval, value)
      else
        Logger.info "CHECK: #{target_name.upcase} #{packet_name.upcase} #{item_name.upcase} == #{value}"
      end
    end

    # Check the converted value of a telmetry item against a condition
    # Always print the value of the telemetry item to STDOUT
    # If the condition check fails, raise an error
    # Supports two signatures:
    # check(target_name, packet_name, item_name, comparison_to_eval)
    # or
    # check('target_name packet_name item_name > 1')
    def check(*args)
      _check(*args) {|tgt,pkt,item| tlm(tgt,pkt,item) }
    end

    # Check the formatted value of a telmetry item against a condition
    # Always print the value of the telemetry item to STDOUT
    # If the condition check fails, raise an error
    # Supports two signatures:
    # check(target_name, packet_name, item_name, comparison_to_eval)
    # or
    # check('target_name packet_name item_name > 1')
    def check_formatted(*args)
      _check(*args) {|tgt,pkt,item| tlm_formatted(tgt,pkt,item) }
    end

    # Check the formatted with units value of a telmetry item against a condition
    # Always print the value of the telemetry item to STDOUT
    # If the condition check fails, raise an error
    # Supports two signatures:
    # check(target_name, packet_name, item_name, comparison_to_eval)
    # or
    # check('target_name packet_name item_name > 1')
    def check_with_units(*args)
      _check(*args) {|tgt,pkt,item| tlm_with_units(tgt,pkt,item) }
    end

    # Check the raw value of a telmetry item against a condition
    # Always print the value of the telemetry item to STDOUT
    # If the condition check fails, raise an error
    # Supports two signatures:
    # check(target_name, packet_name, item_name, comparison_to_eval)
    # or
    # check('target_name packet_name item_name > 1')
    def check_raw(*args)
      _check(*args) {|tgt,pkt,item| tlm_raw(tgt,pkt,item) }
    end

    def _check_tolerance(*args)
      target_name, packet_name, item_name, expected_value, tolerance =
        check_tolerance_process_args(args, 'check_tolerance')
      value = yield(target_name, packet_name, item_name)
      range = (expected_value - tolerance)..(expected_value + tolerance)
      if range.include?(value)
        Logger.info "CHECK: #{target_name.upcase} #{packet_name.upcase} #{item_name.upcase} was within range #{range.first} to #{range.last} with value == #{value}"
      else
        message = "CHECK: #{target_name.upcase} #{packet_name.upcase} #{item_name.upcase} failed to be within range #{range.first} to #{range.last} with value == #{value}"
        if $cmd_tlm_disconnect
          Logger.error message
        else
          raise CheckError, message
        end
      end
    end

    # Check the converted value of a telmetry item against an expected value with a tolerance
    # Always print the value of the telemetry item to STDOUT
    # If the condition check fails, raise an error
    # Supports two signatures:
    # check_tolerance(target_name, packet_name, item_name, expected_value, tolerance)
    # or
    # check_tolerance('target_name packet_name item_name', expected_value, tolerance)
    def check_tolerance(*args)
      _check_tolerance(*args) {|tgt,pkt,item| tlm(tgt,pkt,item) }
    end

    # Check the raw value of a telmetry item against an expected value with a tolerance
    # Always print the value of the telemetry item to STDOUT
    # If the condition check fails, raise an error
    # Supports two signatures:
    # check_tolerance_raw(target_name, packet_name, item_name, expected_value, tolerance)
    # or
    # check_tolerance_raw('target_name packet_name item_name', expected_value, tolerance)
    def check_tolerance_raw(*args)
      _check_tolerance(*args) {|tgt,pkt,item| tlm_raw(tgt,pkt,item) }
    end

    # Check to see if an expression is true without waiting.  If the expression
    # is not true, the script will pause.
    def check_expression(exp_to_eval, context = nil)
      success = cosmos_script_wait_implementation_expression(exp_to_eval, 0, DEFAULT_TLM_POLLING_RATE, context)
      if success
        Logger.info "CHECK: #{exp_to_eval} is TRUE"
      else
        message = "CHECK: #{exp_to_eval} is FALSE"
        if $cmd_tlm_disconnect
          Logger.error message
        else
          raise CheckError, message
        end
      end
    end

    # Wait on an expression to be true.  On a timeout, the script will continue.
    # Supports multiple signatures:
    # wait(time)
    # wait('target_name packet_name item_name > 1', timeout, polling_rate)
    # wait('target_name', 'packet_name', 'item_name', comparison_to_eval, timeout, polling_rate)
    def wait(*args)
      wait_process_args(args, 'wait', :CONVERTED)
    end

    # Wait on an expression to be true.  On a timeout, the script will continue.
    # Supports multiple signatures:
    # wait(time)
    # wait_raw('target_name packet_name item_name > 1', timeout, polling_rate)
    # wait_raw('target_name', 'packet_name', 'item_name', comparison_to_eval, timeout, polling_rate)
    def wait_raw(*args)
      wait_process_args(args, 'wait_raw', :RAW)
    end

    def _wait_tolerance(raw, *args)
      type = (raw ? :RAW : :CONVERTED)
      type_string = 'wait_tolerance'
      type_string << '_raw' if raw
      target_name, packet_name, item_name, expected_value, tolerance, timeout, polling_rate = wait_tolerance_process_args(args, type_string)
      start_time = Time.now
      success, value = cosmos_script_wait_implementation_tolerance(target_name, packet_name, item_name, type, expected_value, tolerance, timeout, polling_rate)
      time = Time.now - start_time
      range = (expected_value - tolerance)..(expected_value + tolerance)
      if success
        Logger.info "WAIT: #{target_name.upcase} #{packet_name.upcase} #{item_name.upcase} was within range #{range.first} to #{range.last} with value == #{value} after waiting #{time} seconds"
      else
        Logger.warn "WAIT: #{target_name.upcase} #{packet_name.upcase} #{item_name.upcase} failed to be within range #{range.first} to #{range.last} with value == #{value} after waiting #{time} seconds"
      end
      time
    end

    # Wait on an expression to be true.  On a timeout, the script will continue.
    # Supports multiple signatures:
    # wait_tolerance('target_name packet_name item_name', expected_value, tolerance, timeout, polling_rate)
    # wait_tolerance('target_name', 'packet_name', 'item_name', expected_value, tolerance, timeout, polling_rate)
    def wait_tolerance(*args)
      _wait_tolerance(false, *args)
    end

    # Wait on an expression to be true.  On a timeout, the script will continue.
    # Supports multiple signatures:
    # wait_tolerance_raw('target_name packet_name item_name', expected_value, tolerance, timeout, polling_rate)
    # wait_tolerance_raw('target_name', 'packet_name', 'item_name', expected_value, tolerance, timeout, polling_rate)
    def wait_tolerance_raw(*args)
      _wait_tolerance(true, *args)
    end

    # Wait on a custom expression to be true
    def wait_expression(exp_to_eval, timeout, polling_rate = DEFAULT_TLM_POLLING_RATE, context = nil)
      start_time = Time.now
      success = cosmos_script_wait_implementation_expression(exp_to_eval, timeout, polling_rate, context)
      time = Time.now - start_time
      if success
        Logger.info "WAIT: #{exp_to_eval} is TRUE after waiting #{time} seconds"
      else
        Logger.warn "WAIT: #{exp_to_eval} is FALSE after waiting #{time} seconds"
      end
      time
    end

    def _wait_check(raw, *args)
      type = (raw ? :RAW : :CONVERTED)
      target_name, packet_name, item_name, comparison_to_eval, timeout, polling_rate = wait_check_process_args(args, 'wait_check')
      start_time = Time.now
      success, value = cosmos_script_wait_implementation(target_name, packet_name, item_name, type, comparison_to_eval, timeout, polling_rate)
      time = Time.now - start_time
      if success
        Logger.info "CHECK: #{target_name.upcase} #{packet_name.upcase} #{item_name.upcase} #{comparison_to_eval} success with value == #{value} after waiting #{time} seconds"
      else
        message = "CHECK: #{target_name.upcase} #{packet_name.upcase} #{item_name.upcase} #{comparison_to_eval} failed with value == #{value} after waiting #{time} seconds"
        if $cmd_tlm_disconnect
          Logger.error message
        else
          raise CheckError, message
        end
      end
      time
    end

    # Wait for the converted value of a telmetry item against a condition or for a timeout
    # and then check against the condition
    # Supports two signatures:
    # wait_check(target_name, packet_name, item_name, comparison_to_eval, timeout, polling_rate)
    # or
    # wait_check('target_name packet_name item_name > 1', timeout, polling_rate)
    def wait_check(*args)
      _wait_check(false, *args)
    end

    # Wait for the raw value of a telmetry item against a condition or for a timeout
    # and then check against the condition
    # Supports two signatures:
    # wait_check_raw(target_name, packet_name, item_name, comparison_to_eval, timeout, polling_rate)
    # or
    # wait_check_raw('target_name packet_name item_name > 1', timeout, polling_rate)
    def wait_check_raw(*args)
      _wait_check(true, *args)
    end

    def _wait_check_tolerance(raw, *args)
      type_string = 'wait_check_tolerance'
      type_string << '_raw' if raw
      type = (raw ? :RAW : :CONVERTED)
      target_name, packet_name, item_name, expected_value, tolerance, timeout, polling_rate = wait_tolerance_process_args(args, type_string)
      start_time = Time.now
      success, value = cosmos_script_wait_implementation_tolerance(target_name, packet_name, item_name, type, expected_value, tolerance, timeout, polling_rate)
      time = Time.now - start_time
      range = (expected_value - tolerance)..(expected_value + tolerance)
      if success
        Logger.info "CHECK: #{target_name.upcase} #{packet_name.upcase} #{item_name.upcase} was within range #{range.first} to #{range.last} with value == #{value} after waiting #{time} seconds"
      else
        message = "CHECK: #{target_name.upcase} #{packet_name.upcase} #{item_name.upcase} failed to be within range #{range.first} to #{range.last} with value == #{value} after waiting #{time} seconds"
        if $cmd_tlm_disconnect
          Logger.error message
        else
          raise CheckError, message
        end
      end
      time
    end

    def wait_check_tolerance(*args)
      _wait_check_tolerance(false, *args)
    end

    def wait_check_tolerance_raw(*args)
      _wait_check_tolerance(true, *args)
    end

    # Wait on an expression to be true.  On a timeout, the script will pause.
    def wait_check_expression(exp_to_eval,
                              timeout,
                              polling_rate = DEFAULT_TLM_POLLING_RATE,
                              context = nil)
      start_time = Time.now
      success = cosmos_script_wait_implementation_expression(exp_to_eval,
                                                             timeout,
                                                             polling_rate,
                                                             context)
      time = Time.now - start_time
      if success
        Logger.info "CHECK: #{exp_to_eval} is TRUE after waiting #{time} seconds"
      else
        message = "CHECK: #{exp_to_eval} is FALSE after waiting #{time} seconds"
        if $cmd_tlm_disconnect
          Logger.error message
        else
          raise CheckError, message
        end
      end
      time
    end
    alias wait_expression_stop_on_timeout wait_check_expression

    # Wait for a telemetry packet to be received a certain number of times or timeout
    def _wait_packet(check,
                     target_name,
                     packet_name,
                     num_packets,
                     timeout,
                     polling_rate = DEFAULT_TLM_POLLING_RATE)
      type = (check ? 'CHECK' : 'WAIT')
      initial_count = tlm(target_name, packet_name, 'RECEIVED_COUNT')
      start_time = Time.now
      success, value = cosmos_script_wait_implementation(target_name,
                                                         packet_name,
                                                         'RECEIVED_COUNT',
                                                         :CONVERTED,
                                                         ">= #{initial_count + num_packets}",
                                                         timeout,
                                                         polling_rate)
      time = Time.now - start_time
      if success
        Logger.info "#{type}: #{target_name.upcase} #{packet_name.upcase} received #{value - initial_count} times after waiting #{time} seconds"
      else
        message = "#{type}: #{target_name.upcase} #{packet_name.upcase} expected to be received #{num_packets} times but only received #{value - initial_count} times after waiting #{time} seconds"
        if check
          if $cmd_tlm_disconnect
            Logger.error message
          else
            raise CheckError, message
          end
        else
          Logger.warn message
        end
      end
      time
    end

    def wait_packet(target_name,
                    packet_name,
                    num_packets,
                    timeout,
                    polling_rate = DEFAULT_TLM_POLLING_RATE)
      _wait_packet(false, target_name, packet_name, num_packets, timeout, polling_rate)
    end

    # Wait for a telemetry packet to be received a certain number of times or timeout and raise an error
    def wait_check_packet(target_name,
                          packet_name,
                          num_packets,
                          timeout,
                          polling_rate = DEFAULT_TLM_POLLING_RATE)
      _wait_packet(true, target_name, packet_name, num_packets, timeout, polling_rate)
    end

    def get_interface_names
      return $cmd_tlm_server.get_interface_names
    end

    def connect_interface(interface_name, *params)
      return $cmd_tlm_server.connect_interface(interface_name, *params)
    end

    def disconnect_interface(interface_name)
      return $cmd_tlm_server.disconnect_interface(interface_name)
    end

    def interface_state(interface_name)
      return $cmd_tlm_server.interface_state(interface_name)
    end

    def map_target_to_interface(target_name, interface_name)
      return $cmd_tlm_server.map_target_to_interface(target_name, interface_name)
    end

    def get_router_names
      return $cmd_tlm_server.get_router_names
    end

    def connect_router(router_name, *params)
      return $cmd_tlm_server.connect_router(router_name, *params)
    end

    def disconnect_router(router_name)
      return $cmd_tlm_server.disconnect_router(router_name)
    end

    def router_state(router_name)
      return $cmd_tlm_server.router_state(router_name)
    end

    def get_cmd_log_filename(packet_log_writer_name = 'DEFAULT')
      return $cmd_tlm_server.get_cmd_log_filename(packet_log_writer_name)
    end

    def get_tlm_log_filename(packet_log_writer_name = 'DEFAULT')
      return $cmd_tlm_server.get_tlm_log_filename(packet_log_writer_name)
    end

    def start_logging(packet_log_writer_name = 'ALL', label = nil)
      return $cmd_tlm_server.start_logging(packet_log_writer_name, label)
    end

    def stop_logging(packet_log_writer_name = 'ALL')
      return $cmd_tlm_server.stop_logging(packet_log_writer_name)
    end

    def start_cmd_log(packet_log_writer_name = 'ALL', label = nil)
      return $cmd_tlm_server.start_cmd_log(packet_log_writer_name, label)
    end

    def start_tlm_log(packet_log_writer_name = 'ALL', label = nil)
      return $cmd_tlm_server.start_tlm_log(packet_log_writer_name, label)
    end

    def stop_cmd_log(packet_log_writer_name = 'ALL')
      return $cmd_tlm_server.stop_cmd_log(packet_log_writer_name)
    end

    def stop_tlm_log(packet_log_writer_name = 'ALL')
      return $cmd_tlm_server.stop_tlm_log(packet_log_writer_name)
    end

    def start_raw_logging_interface(interface_name = 'ALL')
      return $cmd_tlm_server.start_raw_logging_interface(interface_name)
    end

    def stop_raw_logging_interface(interface_name = 'ALL')
      return $cmd_tlm_server.stop_raw_logging_interface(interface_name)
    end

    def start_raw_logging_router(router_name = 'ALL')
      return $cmd_tlm_server.start_raw_logging_router(router_name)
    end

    def stop_raw_logging_router(router_name = 'ALL')
      return $cmd_tlm_server.stop_raw_logging_router(router_name)
    end

    def get_server_message_log_filename
      return $cmd_tlm_server.get_server_message_log_filename
    end

    def start_new_server_message_log
      return $cmd_tlm_server.start_new_server_message_log
    end

    #######################################
    # Methods accessing tlm_viewer
    #######################################

    def display(display_name, x_pos = nil, y_pos = nil)
      tlm_viewer = JsonDRbObject.new "localhost", System.ports['TLMVIEWER_API']
      begin
        tlm_viewer.display(display_name, x_pos, y_pos)
        tlm_viewer.disconnect
      rescue DRb::DRbConnError
        # No Listening Tlm Viewer - So Start One
        if Kernel.is_windows?
          Cosmos.run_process('rubyw "' + File.join(Cosmos::USERPATH, 'tools', 'TlmViewer') + '"' + " --system #{File.basename(System.initial_filename)}")
        elsif Kernel.is_mac? and File.exist?(File.join(Cosmos::USERPATH, 'tools', 'mac', 'TlmViewer.app'))
          Cosmos.run_process('open "' + File.join(Cosmos::USERPATH, 'tools', 'mac', 'TlmViewer.app') + '"' + " --args --system #{File.basename(System.initial_filename)}")
        else
          Cosmos.run_process('ruby "' + File.join(Cosmos::USERPATH, 'tools', 'TlmViewer') + '"' + " --system #{File.basename(System.initial_filename)}")
        end
        sleep(5)
        begin
          tlm_viewer.display(display_name, x_pos, y_pos)
          tlm_viewer.disconnect
        rescue DRb::DRbConnError
          raise "Unable to Successfully Start Listening Telemetry Viewer: #{display_name} could not be displayed"
        rescue Errno::ENOENT
          raise "Display Screen File: #{display_name}.txt does not exist"
        end
      rescue Errno::ENOENT
        raise "Display Screen File: #{display_name}.txt does not exist"
      end
    end

    def clear(display_name)
      tlm_viewer = JsonDRbObject.new "localhost", System.ports['TLMVIEWER_API']
      begin
        tlm_viewer.clear(display_name)
        tlm_viewer.disconnect
      rescue DRb::DRbConnError
        # No Listening Tlm Viewer - So Start One
        if Kernel.is_windows?
          Cosmos.run_process('rubyw "' + File.join(Cosmos::USERPATH, 'tools', 'TlmViewer') + '"' + " --system #{File.basename(System.initial_filename)}")
        elsif Kernel.is_mac? and File.exist?(File.join(Cosmos::USERPATH, 'tools', 'mac', 'TlmViewer.app'))
          Cosmos.run_process('open "' + File.join(Cosmos::USERPATH, 'tools', 'mac', 'TlmViewer.app') + '"' + " --args --system #{File.basename(System.initial_filename)}")
        else
          Cosmos.run_process('ruby "' + File.join(Cosmos::USERPATH, 'tools', 'TlmViewer') + '"' + " --system #{File.basename(System.initial_filename)}")
        end
        sleep(5)
        begin
          tlm_viewer.clear(display_name)
          tlm_viewer.disconnect
        rescue DRb::DRbConnError
          raise "Unable to Successfully Start Listening Telemetry Viewer: #{display_name} could not be cleared"
        rescue Errno::ENOENT
          raise "Display Screen File: #{display_name}.txt does not exist"
        end
      rescue Errno::ENOENT
        raise "Display Screen File: #{display_name}.txt does not exist"
      end
    end

    #######################################
    # Methods accessing script runner
    #######################################

    def set_line_delay(delay)
      if defined? ScriptRunnerFrame
        ScriptRunnerFrame.line_delay = delay if delay >= 0.0
      end
    end

    def get_line_delay
      if defined? ScriptRunnerFrame
        ScriptRunnerFrame.line_delay
      end
    end

    def get_scriptrunner_message_log_filename
      filename = nil
      if defined? ScriptRunnerFrame
        filename = ScriptRunnerFrame.instance.message_log.filename if ScriptRunnerFrame.instance and ScriptRunnerFrame.instance.message_log
      end
      return filename
    end

    def start_new_scriptrunner_message_log
      if defined? ScriptRunnerFrame
        # A new log will be created at the next message
        ScriptRunnerFrame.instance.stop_message_log if ScriptRunnerFrame.instance
      end
    end

    def disable_instrumentation
      if defined? ScriptRunnerFrame and ScriptRunnerFrame.instance
        ScriptRunnerFrame.instance.use_instrumentation = false
        begin
          yield
        ensure
          ScriptRunnerFrame.instance.use_instrumentation = true
        end
      else
        yield
      end
    end

    def set_stdout_max_lines(max_lines)
      if defined? ScriptRunnerFrame and ScriptRunnerFrame.instance
        ScriptRunnerFrame.instance.stdout_max_lines = max_lines
      end
    end

    #######################################
    # Methods for debugging
    #######################################

    def insert_return(*params)
      if defined? ScriptRunnerFrame
        if ScriptRunnerFrame.instance
          ScriptRunnerFrame.instance.inline_return = true
          ScriptRunnerFrame.instance.inline_return_params = params
        end
      end
    end

    def step_mode
      if defined? ScriptRunnerFrame
        ScriptRunnerFrame.step_mode = true
      end
    end

    def run_mode
      if defined? ScriptRunnerFrame
        ScriptRunnerFrame.step_mode = false
      end
    end

    def show_backtrace(value = true)
      if defined? ScriptRunnerFrame
        ScriptRunnerFrame.show_backtrace = value
      end
    end

    ##########################################
    # End Methods accessing other systems
    ##########################################

    def start(procedure_name)
      # Handle not-giving an extension
      procedure_name_with_extension = nil
      procedure_name_with_extension = procedure_name + '.rb' if File.extname(procedure_name).empty?

      file_text = ''
      path = nil

      # Find filename in search path
      ($:).each do |directory|
        if File.exist?(directory + '/' + procedure_name) and not File.directory?(directory + '/' + procedure_name)
          path = directory + '/' + procedure_name
          break
        end

        if procedure_name_with_extension and File.exist?(directory + '/' + procedure_name_with_extension)
          procedure_name = procedure_name_with_extension
          path = directory + '/' + procedure_name
          break
        end
      end

      # Handle absolute path
      path = procedure_name if !path and File.exist?(procedure_name)
      path = procedure_name_with_extension if !path and procedure_name_with_extension and File.exist?(procedure_name_with_extension)

      raise "Procedure not found : #{procedure_name}" unless path

      if defined? ScriptRunnerFrame and ScriptRunnerFrame.instance
        result = false
        md5 = nil
        begin
          md5 = Cosmos.md5_files([path]).hexdigest
        rescue Exception => error
          raise "Error calculating md5 on procedure file : #{path}"
        end

        # Check RAM based instrumented cache
        instrumented_cache  = ScriptRunnerFrame.instrumented_cache[path]
        instrumented_script = nil
        if instrumented_cache and md5 == instrumented_cache[1]
          # Use cached instrumentation
          instrumented_script = instrumented_cache[0]
        else
          use_file_cache = true
          cache_filename = nil
          flat_path = nil

          # Check for cache directory existence
          Cosmos.set_working_dir do
            cache_path = File.join(System.paths['TMP'], 'script_runner')
            unless File.directory?(cache_path)
              # Try to create .cache directory
              begin
                Dir.mkdir(cache_path)
              rescue
                use_file_cache = false
              end
            end

            if use_file_cache
              # Check file based instrumented cache
              flat_path = path.tr("/", "_").gsub("\\", "_").tr(":", "_").tr(" ", "_")
              flat_path_with_md5 = flat_path + '_' + md5
              cache_filename = File.join(cache_path, flat_path_with_md5)
            end

            if use_file_cache and File.exist?(cache_filename)
              # Use file cached instrumentation
              File.open(cache_filename, 'r') {|file| instrumented_script = file.read}
            else
              # Have to instrument
              result = true

              # Build instrumentation
              begin
                file_text = File.read(path)
              rescue Exception => error
                raise "Error reading procedure file : #{path}"
              end

              instrumented_script = ScriptRunnerFrame.instrument_script(file_text, path, true)

              # Cache instrumentation into file
              if use_file_cache
                begin
                  File.open(cache_filename, 'w') {|file| file.write(instrumented_script)}
                rescue
                  # Oh well, failed to write cache file
                end
              end
            end
          end

          # Cache instrumentation into RAM
          ScriptRunnerFrame.instrumented_cache[path] = [instrumented_script, md5]
        end

        Object.class_eval(instrumented_script, path, 1)
      else # No ScriptRunnerFrame so just start it locally
        result = true

        begin
          Kernel::load(path)
        rescue LoadError => error
          raise RuntimeError.new("Error loading : #{procedure_name} : #{error.message}")
        end
      end
      result
    end

    # Require an additional ruby file
    def load_utility(procedure_name)
      result = false
      if defined? ScriptRunnerFrame and ScriptRunnerFrame.instance
        saved = ScriptRunnerFrame.instance.use_instrumentation
        begin
          ScriptRunnerFrame.instance.use_instrumentation = false
          result = start(procedure_name)
        ensure
          ScriptRunnerFrame.instance.use_instrumentation = saved
        end
      else # Just call start
        result = start(procedure_name)
      end
      result
    end
    alias require_utility load_utility

    ##########################################
    # Protected Methods
    ##########################################

    def check_process_args(args, function_name)
      case args.length
      when 1
        target_name, packet_name, item_name, comparison_to_eval = extract_fields_from_check_text(args[0])
      when 4
        target_name        = args[0]
        packet_name        = args[1]
        item_name          = args[2]
        comparison_to_eval = args[3]
      else
        # Invalid number of arguments
        raise "ERROR: Invalid number of arguments (#{args.length}) passed to #{function_name}()"
      end
      return [target_name, packet_name, item_name, comparison_to_eval]
    end

    def check_tolerance_process_args(args, function_name)
      case args.length
      when 3
        target_name, packet_name, item_name = extract_fields_from_tlm_text(args[0])
        expected_value = args[1]
        tolerance = args[2]
      when 5
        target_name = args[0]
        packet_name = args[1]
        item_name = args[2]
        expected_value = args[3]
        tolerance = args[4]
      else
        # Invalid number of arguments
        raise "ERROR: Invalid number of arguments (#{args.length}) passed to #{function_name}()"
      end
      return [target_name, packet_name, item_name, expected_value, tolerance]
    end

    def wait_process_args(args, function_name, value_type)
      time = nil

      case args.length
      when 0
        start_time = Time.now
        cosmos_script_sleep()
        time = Time.now - start_time
        Logger.info("WAIT: Indefinite for actual time of #{time} seconds")
      when 1
        if args[0].kind_of? Numeric
          start_time = Time.now
          cosmos_script_sleep(args[0])
          time = Time.now - start_time
          Logger.info("WAIT: #{args[0]} seconds with actual time of #{time} seconds")
        else
          raise "Non-numeric wait time specified"
        end
      when 2, 3
        target_name, packet_name, item_name, comparison_to_eval = extract_fields_from_check_text(args[0])
        timeout = args[1]
        if args.length == 3
          polling_rate = args[2]
        else
          polling_rate = DEFAULT_TLM_POLLING_RATE
        end
        start_time = Time.now
        success, value = cosmos_script_wait_implementation(target_name, packet_name, item_name, value_type, comparison_to_eval, timeout, polling_rate)
        time = Time.now - start_time
        if success
          Logger.info "WAIT: #{target_name.upcase} #{packet_name.upcase} #{item_name.upcase} #{comparison_to_eval} success with value == #{value} after waiting #{time} seconds"
        else
          Logger.warn "WAIT: #{target_name.upcase} #{packet_name.upcase} #{item_name.upcase} #{comparison_to_eval} failed with value == #{value} after waiting #{time} seconds"
        end
      when 5, 6
        target_name = args[0]
        packet_name = args[1]
        item_name = args[2]
        comparison_to_eval = args[3]
        timeout = args[4]
        if args.length == 6
          polling_rate = args[5]
        else
          polling_rate = DEFAULT_TLM_POLLING_RATE
        end
        start_time = Time.now
        success, value = cosmos_script_wait_implementation(target_name, packet_name, item_name, value_type, comparison_to_eval, timeout, polling_rate)
        time = Time.now - start_time
        if success
          Logger.info "WAIT: #{target_name.upcase} #{packet_name.upcase} #{item_name.upcase} #{comparison_to_eval} success with value == #{value} after waiting #{time} seconds"
        else
          Logger.warn "WAIT: #{target_name.upcase} #{packet_name.upcase} #{item_name.upcase} #{comparison_to_eval} failed with value == #{value} after waiting #{time} seconds"
        end
      else
        # Invalid number of arguments
        raise "ERROR: Invalid number of arguments (#{args.length}) passed to #{function_name}()"
      end
      time
    end

    def wait_tolerance_process_args(args, function_name)
      case args.length
      when 4, 5
        target_name, packet_name, item_name = extract_fields_from_tlm_text(args[0])
        expected_value = args[1]
        tolerance = args[2]
        timeout = args[3]
        if args.length == 5
          polling_rate = args[4]
        else
          polling_rate = DEFAULT_TLM_POLLING_RATE
        end
      when 6, 7
        target_name = args[0]
        packet_name = args[1]
        item_name = args[2]
        expected_value = args[3]
        tolerance = args[4]
        timeout = args[5]
        if args.length == 7
          polling_rate = args[6]
        else
          polling_rate = DEFAULT_TLM_POLLING_RATE
        end
      else
        # Invalid number of arguments
        raise "ERROR: Invalid number of arguments (#{args.length}) passed to #{function_name}()"
      end
      return [target_name, packet_name, item_name, expected_value, tolerance, timeout, polling_rate]
    end

    def wait_check_process_args(args, function_name)
      case args.length
      when 2,3
        target_name, packet_name, item_name, comparison_to_eval = extract_fields_from_check_text(args[0])
        timeout = args[1]
        if args.length == 3
          polling_rate = args[2]
        else
          polling_rate = DEFAULT_TLM_POLLING_RATE
        end
      when 5,6
        target_name = args[0]
        packet_name = args[1]
        item_name = args[2]
        comparison_to_eval = args[3]
        timeout = args[4]
        if args.length == 6
          polling_rate = args[5]
        else
          polling_rate = DEFAULT_TLM_POLLING_RATE
        end
      else
        # Invalid number of arguments
        raise "ERROR: Invalid number of arguments (#{args.length}) passed to #{function_name}()"
      end
      return [target_name, packet_name, item_name, comparison_to_eval, timeout, polling_rate]
    end

    # sleep in a script - returns true if canceled mid sleep
    def cosmos_script_sleep(sleep_time = nil)
      return false if $cmd_tlm_disconnect
      if defined? ScriptRunnerFrame and ScriptRunnerFrame.instance
        sleep_time = 30000000 unless sleep_time # Handle infinite wait
        if sleep_time > 0.0
          end_time = Time.now + sleep_time
          until (Time.now >= end_time)
            sleep(0.01)
            if ScriptRunnerFrame.instance.pause?
              ScriptRunnerFrame.instance.perform_pause
              return true
            end
            return true if ScriptRunnerFrame.instance.go?
            raise StopScript if ScriptRunnerFrame.instance.stop?
          end
        end
      else
        if sleep_time
          sleep(sleep_time)
        else
          print 'Infinite Wait - Press Enter to Continue: '
          gets()
        end
      end
      return false
    end

    def _cosmos_script_wait_implementation(target_name, packet_name, item_name, value_type, timeout, polling_rate)
      end_time = Time.now + timeout
      exp_to_eval = yield

      while true
        work_start = Time.now
        value = tlm_variable(target_name, packet_name, item_name, value_type)
        if eval(exp_to_eval)
          return true, value
        end
        break if Time.now >= end_time || $cmd_tlm_disconnect

        delta = Time.now - work_start
        sleep_time = polling_rate - delta
        end_delta = end_time - Time.now
        sleep_time = end_delta if end_delta < sleep_time
        sleep_time = 0 if sleep_time < 0
        canceled = cosmos_script_sleep(sleep_time)

        if canceled
          value = tlm_variable(target_name, packet_name, item_name, value_type)
          if eval(exp_to_eval)
            return true, value
          else
            return false, value
          end
        end
      end

      return false, value
    end

    # Wait for a converted telemetry item to pass a comparison
    def cosmos_script_wait_implementation(target_name, packet_name, item_name, value_type, comparison_to_eval, timeout, polling_rate = DEFAULT_TLM_POLLING_RATE)
      _cosmos_script_wait_implementation(target_name, packet_name, item_name, value_type, timeout, polling_rate) do
        "value " + comparison_to_eval
      end
    end

    def cosmos_script_wait_implementation_tolerance(target_name, packet_name, item_name, value_type, expected_value, tolerance, timeout, polling_rate = DEFAULT_TLM_POLLING_RATE)
      _cosmos_script_wait_implementation(target_name, packet_name, item_name, value_type, timeout, polling_rate) do
        "((#{expected_value} - #{tolerance})..(#{expected_value} + #{tolerance})).include? value"
      end
    end

    # Wait on an expression to be true.
    def cosmos_script_wait_implementation_expression(exp_to_eval, timeout, polling_rate, context)
      end_time = Time.now + timeout
      context = ScriptRunnerFrame.instance.script_binding if !context and defined? ScriptRunnerFrame and ScriptRunnerFrame.instance

      while true
        work_start = Time.now
        if eval(exp_to_eval, context)
          return true
        end
        break if Time.now >= end_time

        delta = Time.now - work_start
        sleep_time = polling_rate - delta
        end_delta = end_time - Time.now
        sleep_time = end_delta if end_delta < sleep_time
        sleep_time = 0 if sleep_time < 0
        canceled = cosmos_script_sleep(sleep_time)

        if canceled
          if eval(exp_to_eval, context)
            return true
          else
            return nil
          end
        end
      end

      return nil
    end

    def check_eval(target_name, packet_name, item_name, comparison_to_eval, value)
      string = "value " + comparison_to_eval
      if eval(string)
        Logger.info "CHECK: #{target_name.upcase} #{packet_name.upcase} #{item_name.upcase} #{comparison_to_eval} success with value == #{value}"
      else
        message = "CHECK: #{target_name.upcase} #{packet_name.upcase} #{item_name.upcase} #{comparison_to_eval} failed with value == #{value}"
        if $cmd_tlm_disconnect
          Logger.error message
        else
          raise CheckError, message
        end
      end
    end

    def build_cmd_output_string(target_name, cmd_name, cmd_params, raw = false)
      if raw
        output_string = 'cmd_raw("'
      else
        output_string = 'cmd("'
      end
      output_string << target_name + ' ' + cmd_name
      if cmd_params.nil? or cmd_params.empty?
        output_string << '")'
      else
        params = []
        cmd_params.each do |key, value|
          if value.class == String
            if value.convert_to_value.class == String
              value = value.inspect
              if value.length > 256
                value = value[0..255] + "...'"
              end
              value.tr!('"',"'")
            end
          end
          params << "#{key} #{value}"
        end
        params = params.join(", ")
        output_string << ' with ' + params + '")'
      end
      return output_string
    end

    def prompt_for_hazardous(target_name, cmd_name, hazardous_description)
      message = "Warning: Command #{target_name} #{cmd_name} is Hazardous. "
      message << "\n#{hazardous_description}\n" if hazardous_description
      message << "Send? (y,n): "
      print message
      answer = gets.chomp
      if answer.downcase == 'y'
        return true
      else
        return false
      end
    end

    def prompt_for_script_abort
      print "Stop running script? (y,n): "
      answer = gets.chomp
      if answer.downcase == 'y'
        exit
      else
        return false # Not aborted - Retry
      end
    end

    def prompt_to_continue(string)
      print "#{string}: "
      gets.chomp
    end

    def prompt_message_box(string, buttons)
      print "#{string} (#{buttons.join(", ")}): "
      gets.chomp
    end

    ################################
    # Module setup and config
    ################################

    def set_cmd_tlm_disconnect(disconnect = false, config_file = CmdTlmServer::DEFAULT_CONFIG_FILE)
      if disconnect != $cmd_tlm_disconnect
        $cmd_tlm_disconnect = disconnect
        initialize_script_module(config_file)
      end
    end

    def get_cmd_tlm_disconnect
      return $cmd_tlm_disconnect
    end

    def initialize_script_module(config_file = CmdTlmServer::DEFAULT_CONFIG_FILE)
      if $cmd_tlm_disconnect
        # Start up a standalone CTS in disconnected mode
        $cmd_tlm_server = CmdTlmServer.new(config_file, false, true)
      else
        # Start a Json connect to the real CTS server
        $cmd_tlm_server = JsonDRbObject.new('127.0.0.1', System.ports['CTS_API'])
      end
    end

    def self.included(base)
      $cmd_tlm_disconnect = false
      $cmd_tlm_server = nil
      initialize_script_module()
    end

    def script_disconnect
      $cmd_tlm_server.disconnect if $cmd_tlm_server && !$cmd_tlm_disconnect
    end

    def shutdown_cmd_tlm
      $cmd_tlm_server.shutdown if $cmd_tlm_server && !$cmd_tlm_disconnect
    end

  end # module Script

end # module Cosmos
