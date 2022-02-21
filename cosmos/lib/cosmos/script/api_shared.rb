# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
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

require 'cosmos/script/extract'

module Cosmos
  module ApiShared
    include Extract

    DEFAULT_TLM_POLLING_RATE = 0.25

    private

    # Check the converted value of a telmetry item against a condition.
    # Always print the value of the telemetry item to STDOUT.
    # If the condition check fails, raise an error.
    #
    # Supports two signatures:
    # check(target_name, packet_name, item_name, comparison_to_eval)
    # check('target_name packet_name item_name > 1')
    #
    # @param args [String|Array<String>] See the description for calling style
    # @param type [Symbol] Telemetry type, :RAW, :CONVERTED (default), :FORMATTED, or :WITH_UNITS
    def check(*args, type: :CONVERTED, scope: $cosmos_scope, token: $cosmos_token)
      _check(*args, scope: scope) { |tgt, pkt, item| tlm(tgt, pkt, item, type: type, scope: scope, token: token) }
    end

    # @deprecated Use check with type: :RAW
    def check_raw(*args, scope: $cosmos_scope, token: $cosmos_token)
      check(*args, type: :RAW, scope: scope, token: token)
    end

    # @deprecated Use check with type: :FORMATTED
    def check_formatted(*args, scope: $cosmos_scope, token: $cosmos_token)
      check(*args, type: :FORMATTED, scope: scope, token: token)
    end

    # @deprecated Use check with type: :WITH_UNITS
    def check_with_units(*args, scope: $cosmos_scope, token: $cosmos_token)
      check(*args, type: :WITH_UNITS, scope: scope, token: token)
    end

    # Executes the passed method and expects an exception to be raised.
    # Raises a CheckError if an Exception is not raised.
    # Usage:
    #   check_exception(method_name, method_params}
    def check_exception(method_name, *args, **kwargs)
      orig_kwargs = kwargs.clone
      kwargs[:scope] = $cosmos_scope unless kwargs[:scope]
      kwargs[:token] = $cosmos_token unless kwargs[:token]
      send(method_name.intern, *args, **kwargs)
      method = "#{method_name}(#{args.join(", ")}"
      method += ", #{orig_kwargs}" unless orig_kwargs.empty?
      method += ")"
    rescue Exception => error
      Logger.info "CHECK: #{method} raised #{error.class}:#{error.message}"
    else
      raise(CheckError, "#{method} should have raised an exception but did not.")
    end

    # Check the converted value of a telmetry item against an expected value with a tolerance.
    # Always print the value of the telemetry item to STDOUT. If the condition check fails, raise an error.
    #
    # Supports two signatures:
    # check_tolerance(target_name, packet_name, item_name, expected_value, tolerance)
    # check_tolerance('target_name packet_name item_name', expected_value, tolerance)
    #
    # @param args [String|Array<String>] See the description for calling style
    # @param type [Symbol] Telemetry type, :RAW or :CONVERTED (default)
    def check_tolerance(*args, type: :CONVERTED, scope: $cosmos_scope, token: $cosmos_token)
      raise "Invalid type '#{type}' for check_tolerance" unless %i(RAW CONVERTED).include?(type)

      target_name, packet_name, item_name, expected_value, tolerance =
        _check_tolerance_process_args(args, scope: scope, token: token)
      value = tlm(target_name, packet_name, item_name, type: type, scope: scope, token: token)
      if value.is_a?(Array)
        expected_value, tolerance = array_tolerance_process_args(value.size, expected_value, tolerance, 'check_tolerance', scope: scope, token: token)

        message = ""
        all_checks_ok = true
        value.size.times do |i|
          range = (expected_value[i] - tolerance[i]..expected_value[i] + tolerance[i])
          check_str = "CHECK: #{_upcase(target_name, packet_name, item_name)}[#{i}]"
          range_str = "range #{range.first} to #{range.last} with value == #{value[i]}"
          if range.include?(value[i])
            message << "#{check_str} was within #{range_str}\n"
          else
            message << "#{check_str} failed to be within #{range_str}\n"
            all_checks_ok = false
          end
        end

        if all_checks_ok
          Logger.info message
        else
          if $disconnect
            Logger.error message
          else
            raise CheckError, message
          end
        end
      else
        range = (expected_value - tolerance)..(expected_value + tolerance)
        check_str = "CHECK: #{_upcase(target_name, packet_name, item_name)}"
        range_str = "range #{range.first} to #{range.last} with value == #{value}"
        if range.include?(value)
          Logger.info "#{check_str} was within #{range_str}"
        else
          message = "#{check_str} failed to be within #{range_str}"
          if $disconnect
            Logger.error message
          else
            raise CheckError, message
          end
        end
      end
    end

    # @deprecated Use check_tolerance with type: :RAW
    def check_tolerance_raw(*args, scope: $cosmos_scope, token: $cosmos_token)
      check_tolerance(*args, type: :RAW, scope: scope, token: token)
    end

    # Check to see if an expression is true without waiting.  If the expression
    # is not true, the script will pause.
    def check_expression(exp_to_eval, context = nil, scope: $cosmos_scope, token: $cosmos_token)
      success = cosmos_script_wait_implementation_expression(exp_to_eval, 0, DEFAULT_TLM_POLLING_RATE, context, scope: scope, token: token)
      if success
        Logger.info "CHECK: #{exp_to_eval} is TRUE"
      else
        message = "CHECK: #{exp_to_eval} is FALSE"
        if $disconnect
          Logger.error message
        else
          raise CheckError, message
        end
      end
    end

    # Wait on an expression to be true. On a timeout, the script will continue.
    #
    # Supports multiple signatures:
    # wait(time)
    # wait('target_name packet_name item_name > 1', timeout, polling_rate)
    # wait('target_name', 'packet_name', 'item_name', comparison_to_eval, timeout, polling_rate)
    #
    # @param args [String|Array<String>] See the description for calling style
    # @param type [Symbol] Telemetry type, :RAW, :CONVERTED (default), :FORMATTED, or :WITH_UNITS
    def wait(*args, type: :CONVERTED, scope: $cosmos_scope, token: $cosmos_token)
      time = nil

      case args.length
      # wait() # indefinitely until they click Go
      when 0
        start_time = Time.now.sys
        cosmos_script_sleep()
        time = Time.now.sys - start_time
        Logger.info("WAIT: Indefinite for actual time of #{time} seconds")

      # wait(5) # absolute wait time
      when 1
        if args[0].kind_of? Numeric
          start_time = Time.now.sys
          cosmos_script_sleep(args[0])
          time = Time.now.sys - start_time
          Logger.info("WAIT: #{args[0]} seconds with actual time of #{time} seconds")
        else
          raise "Non-numeric wait time specified"
        end

      # wait('target_name packet_name item_name > 1', timeout, polling_rate) # polling_rate is optional
      when 2, 3
        target_name, packet_name, item_name, comparison_to_eval = extract_fields_from_check_text(args[0])
        timeout = args[1]
        if args.length == 3
          polling_rate = args[2]
        else
          polling_rate = DEFAULT_TLM_POLLING_RATE
        end
        _execute_wait(target_name, packet_name, item_name, type, comparison_to_eval, timeout, polling_rate, scope: scope, token: token)

      # wait('target_name', 'packet_name', 'item_name', comparison_to_eval, timeout, polling_rate) # polling_rate is optional
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
        _execute_wait(target_name, packet_name, item_name, type, comparison_to_eval, timeout, polling_rate, scope: scope, token: token)

      else
        # Invalid number of arguments
        raise "ERROR: Invalid number of arguments (#{args.length}) passed to wait()"
      end
      time
    end

    # @deprecated Use wait with type: :RAW
    def wait_raw(*args, scope: $cosmos_scope, token: $cosmos_token)
      wait(*args, type: :RAW, scope: scope, token: token)
    end

    # Wait on an expression to be true. On a timeout, the script will continue.
    #
    # Supports two signatures:
    # wait_tolerance('target_name packet_name item_name', expected_value, tolerance, timeout, polling_rate)
    # wait_tolerance('target_name', 'packet_name', 'item_name', expected_value, tolerance, timeout, polling_rate)
    #
    # @param args [String|Array<String>] See the description for calling style
    # @param type [Symbol] Telemetry type, :RAW or :CONVERTED (default)
    def wait_tolerance(*args, type: :CONVERTED, scope: $cosmos_scope, token: $cosmos_token)
      raise "Invalid type '#{type}' for wait_tolerance" unless %i(RAW CONVERTED).include?(type)

      target_name, packet_name, item_name, expected_value, tolerance, timeout, polling_rate = _wait_tolerance_process_args(args, scope: scope, token: token)
      start_time = Time.now.sys
      value = tlm(target_name, packet_name, item_name, type: type, scope: scope, token: token)
      if value.is_a?(Array)
        expected_value, tolerance = array_tolerance_process_args(value.size, expected_value, tolerance, 'wait_tolerance', scope: scope, token: token)

        success, value = cosmos_script_wait_implementation_array_tolerance(value.size, target_name, packet_name, item_name, type, expected_value, tolerance, timeout, polling_rate, scope: scop, token: token)
        time = Time.now.sys - start_time

        message = ""
        value.size.times do |i|
          range = (expected_value[i] - tolerance[i]..expected_value[i] + tolerance[i])
          wait_str = "WAIT: #{_upcase(target_name, packet_name, item_name)}[#{i}]"
          range_str = "range #{range.first} to #{range.last} with value == #{value[i]} after waiting #{time} seconds"
          if range.include?(value[i])
            message << "#{wait_str} was within #{range_str}\n"
          else
            message << "#{wait_str} failed to be within #{range_str}\n"
          end
        end

        if success
          Logger.info message
        else
          Logger.warn message
        end
      else
        success, value = cosmos_script_wait_implementation_tolerance(target_name, packet_name, item_name, type, expected_value, tolerance, timeout, polling_rate, scope: scope, token: token)
        time = Time.now.sys - start_time
        range = (expected_value - tolerance)..(expected_value + tolerance)
        wait_str = "WAIT: #{_upcase(target_name, packet_name, item_name)}"
        range_str = "range #{range.first} to #{range.last} with value == #{value} after waiting #{time} seconds"
        if success
          Logger.info "#{wait_str} was within #{range_str}"
        else
          Logger.warn "#{wait_str} failed to be within #{range_str}"
        end
      end
      time
    end

    # @deprecated Use wait_tolerance with type: :RAW
    def wait_tolerance_raw(*args, scope: $cosmos_scope, token: $cosmos_token)
      wait_tolerance(*args, type: :RAW, scope: scope, token: token)
    end

    # Wait on a custom expression to be true
    def wait_expression(exp_to_eval, timeout, polling_rate = DEFAULT_TLM_POLLING_RATE, context = nil, scope: $cosmos_scope, token: $cosmos_token)
      start_time = Time.now.sys
      success = cosmos_script_wait_implementation_expression(exp_to_eval, timeout, polling_rate, context, scope: scope, token: token)
      time = Time.now.sys - start_time
      if success
        Logger.info "WAIT: #{exp_to_eval} is TRUE after waiting #{time} seconds"
      else
        Logger.warn "WAIT: #{exp_to_eval} is FALSE after waiting #{time} seconds"
      end
      time
    end

    # Wait for the converted value of a telmetry item against a condition or for a timeout
    # and then check against the condition.
    #
    # Supports two signatures:
    # wait_check(target_name, packet_name, item_name, comparison_to_eval, timeout, polling_rate)
    # wait_check('target_name packet_name item_name > 1', timeout, polling_rate)
    #
    # @param args [String|Array<String>] See the description for calling style
    # @param type [Symbol] Telemetry type, :RAW, :CONVERTED (default), :FORMATTED, or :WITH_UNITS
    def wait_check(*args, type: :CONVERTED, scope: $cosmos_scope, token: $cosmos_token, &block)
      target_name, packet_name, item_name, comparison_to_eval, timeout, polling_rate = _wait_check_process_args(args, scope: scope, token: token)
      start_time = Time.now.sys
      success, value = cosmos_script_wait_implementation(target_name, packet_name, item_name, type, comparison_to_eval, timeout, polling_rate, scope: scope, token: token, &block)
      time = Time.now.sys - start_time
      check_str = "CHECK: #{_upcase(target_name, packet_name, item_name)} #{comparison_to_eval}"
      with_value_str = "with value == #{value} after waiting #{time} seconds"
      if success
        Logger.info "#{check_str} success #{with_value_str}"
      else
        message = "#{check_str} failed #{with_value_str}"
        if $disconnect
          Logger.error message
        else
          raise CheckError, message
        end
      end
      time
    end

    # @deprecated use wait_check with type: :RAW
    def wait_check_raw(*args, scope: $cosmos_scope, token: $cosmos_token, &block)
      wait_check(*args, type: :RAW, scope: scope, token: token, &block)
    end

    # Wait for the value of a telmetry item to be within a tolerance of a value
    # and then check against the condition.
    #
    # Supports multiple signatures:
    # wait_tolerance('target_name packet_name item_name', expected_value, tolerance, timeout, polling_rate)
    # wait_tolerance('target_name', 'packet_name', 'item_name', expected_value, tolerance, timeout, polling_rate)
    #
    # @param args [String|Array<String>] See the description for calling style
    # @param type [Symbol] Telemetry type, :RAW or :CONVERTED (default)
    def wait_check_tolerance(*args, type: :CONVERTED, scope: $cosmos_scope, token: $cosmos_token, &block)
      raise "Invalid type '#{type}' for wait_check_tolerance" unless %i(RAW CONVERTED).include?(type)

      target_name, packet_name, item_name, expected_value, tolerance, timeout, polling_rate = _wait_tolerance_process_args(args, scope: scope, token: token)
      start_time = Time.now.sys
      value = tlm(target_name, packet_name, item_name, type: type, scope: scope, token: token)
      if value.is_a?(Array)
        expected_value, tolerance = array_tolerance_process_args(value.size, expected_value, tolerance, 'wait_check_tolerance', scope: scope, token: token)

        success, value = cosmos_script_wait_implementation_array_tolerance(value.size, target_name, packet_name, item_name, type, expected_value, tolerance, timeout, polling_rate, scope: scope, token: token, &block)
        time = Time.now.sys - start_time

        message = ""
        value.size.times do |i|
          range = (expected_value[i] - tolerance[i]..expected_value[i] + tolerance[i])
          check_str = "CHECK: #{_upcase(target_name, packet_name, item_name)}[#{i}]"
          range_str = "range #{range.first} to #{range.last} with value == #{value[i]} after waiting #{time} seconds"
          if range.include?(value[i])
            message << "#{check_str} was within #{range_str}\n"
          else
            message << "#{check_str} failed to be within #{range_str}\n"
          end
        end

        if success
          Logger.info message
        else
          if $disconnect
            Logger.error message
          else
            raise CheckError, message
          end
        end
      else
        success, value = cosmos_script_wait_implementation_tolerance(target_name, packet_name, item_name, type, expected_value, tolerance, timeout, polling_rate, scope: scope, token: token)
        time = Time.now.sys - start_time
        range = (expected_value - tolerance)..(expected_value + tolerance)
        check_str = "CHECK: #{_upcase(target_name, packet_name, item_name)}"
        range_str = "range #{range.first} to #{range.last} with value == #{value} after waiting #{time} seconds"
        if success
          Logger.info "#{check_str} was within #{range_str}"
        else
          message = "#{check_str} failed to be within #{range_str}"
          if $disconnect
            Logger.error message
          else
            raise CheckError, message
          end
        end
      end
      time
    end

    # @deprecated Use wait_check_tolerance with type: :RAW
    def wait_check_tolerance_raw(*args, scope: $cosmos_scope, token: $cosmos_token, &block)
      wait_check_tolerance(*args, type: :RAW, scope: scope, token: token, &block)
    end

    # Wait on an expression to be true.  On a timeout, the script will pause.
    def wait_check_expression(exp_to_eval,
                              timeout,
                              polling_rate = DEFAULT_TLM_POLLING_RATE,
                              context = nil,
                              scope: $cosmos_scope, token: $cosmos_token, &block)
      start_time = Time.now.sys
      success = cosmos_script_wait_implementation_expression(exp_to_eval,
                                                             timeout,
                                                             polling_rate,
                                                             context, scope: scope, token: token, &block)
      time = Time.now.sys - start_time
      if success
        Logger.info "CHECK: #{exp_to_eval} is TRUE after waiting #{time} seconds"
      else
        message = "CHECK: #{exp_to_eval} is FALSE after waiting #{time} seconds"
        if $disconnect
          Logger.error message
        else
          raise CheckError, message
        end
      end
      time
    end
    alias wait_expression_stop_on_timeout wait_check_expression

    def wait_packet(target_name,
                    packet_name,
                    num_packets,
                    timeout,
                    polling_rate = DEFAULT_TLM_POLLING_RATE,
                    scope: $cosmos_scope, token: $cosmos_token)
      _wait_packet(false, target_name, packet_name, num_packets, timeout, polling_rate, scope: scope, token: token)
    end

    # Wait for a telemetry packet to be received a certain number of times or timeout and raise an error
    def wait_check_packet(target_name,
                          packet_name,
                          num_packets,
                          timeout,
                          polling_rate = DEFAULT_TLM_POLLING_RATE,
                          scope: $cosmos_scope, token: $cosmos_token)
      _wait_packet(true, target_name, packet_name, num_packets, timeout, polling_rate, scope: scope, token: token)
    end

    def disable_instrumentation
      if defined? RunningScript and RunningScript.instance
        RunningScript.instance.use_instrumentation = false
        begin
          yield
        ensure
          RunningScript.instance.use_instrumentation = true
        end
      else
        yield
      end
    end

    ###########################################################################
    # Scripts Outside of ScriptRunner Support
    # ScriptRunner overrides these methods to work in the COSMOS cluster
    # They are only here to allow for scripts to have a change to work
    # unaltered outside of the cluster
    ###########################################################################

    def start(procedure_name)
      cached = false
      begin
        Kernel::load(procedure_name)
      rescue LoadError => error
        raise LoadError, "Error loading -- #{procedure_name}\n#{error.message}"
      end
      # Return whether we had to load and instrument this file, i.e. it was not cached
      !cached
    end

    # Require an additional ruby file
    def load_utility(procedure_name)
      return start(procedure_name)
    end
    alias require_utility load_utility

    ###########################################################################
    # Private implementation details
    ###########################################################################

    # Creates a string with the parameters upcased
    def _upcase(target_name, packet_name, item_name)
      "#{target_name.upcase} #{packet_name.upcase} #{item_name.upcase}"
    end

    # Implementaton of the various check commands. It yields back to the
    # caller to allow the return of the value through various telemetry calls.
    # This method should not be called directly by application code.
    def _check(*args, scope: $cosmos_scope, token: $cosmos_token)
      target_name, packet_name, item_name, comparison_to_eval = _check_process_args(args, 'check', scope: scope, token: token)

      value = yield(target_name, packet_name, item_name)
      if comparison_to_eval
        check_eval(target_name, packet_name, item_name, comparison_to_eval, value, scope: scope)
      else
        Logger.info "CHECK: #{_upcase(target_name, packet_name, item_name)} == #{value}"
      end
    end

    def _check_process_args(args, function_name, scope: $cosmos_scope, token: $cosmos_token)
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

    def _check_tolerance_process_args(args, scope: $cosmos_scope, token: $cosmos_token)
      case args.length
      when 3
        target_name, packet_name, item_name = extract_fields_from_tlm_text(args[0])
        expected_value = args[1]
        if args[2].is_a?(Array)
          tolerance = args[2].map!(&:abs)
        else
          tolerance = args[2].abs
        end
      when 5
        target_name = args[0]
        packet_name = args[1]
        item_name = args[2]
        expected_value = args[3]
        if args[4].is_a?(Array)
          tolerance = args[4].map!(&:abs)
        else
          tolerance = args[4].abs
        end
      else
        # Invalid number of arguments
        raise "ERROR: Invalid number of arguments (#{args.length}) passed to check_tolerance()"
      end
      return [target_name, packet_name, item_name, expected_value, tolerance]
    end

    # Wait for a telemetry packet to be received a certain number of times or timeout
    def _wait_packet(check,
                     target_name,
                     packet_name,
                     num_packets,
                     timeout,
                     polling_rate = DEFAULT_TLM_POLLING_RATE,
                     scope: $cosmos_scope, token: $cosmos_token)
      type = (check ? 'CHECK' : 'WAIT')
      initial_count = tlm(target_name, packet_name, 'RECEIVED_COUNT', scope: scope, token: token)
      start_time = Time.now.sys
      success, value = cosmos_script_wait_implementation(target_name,
                                                         packet_name,
                                                         'RECEIVED_COUNT',
                                                         :CONVERTED,
                                                         ">= #{initial_count + num_packets}",
                                                         timeout,
                                                         polling_rate,
                                                         scope: scope,
                                                         token: token)
      time = Time.now.sys - start_time
      if success
        Logger.info "#{type}: #{target_name.upcase} #{packet_name.upcase} received #{value - initial_count} times after waiting #{time} seconds"
      else
        message = "#{type}: #{target_name.upcase} #{packet_name.upcase} expected to be received #{num_packets} times but only received #{value - initial_count} times after waiting #{time} seconds"
        if check
          if $disconnect
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

    def _execute_wait(target_name, packet_name, item_name, value_type, comparison_to_eval, timeout, polling_rate, scope: $cosmos_scope, token: $cosmos_token)
      start_time = Time.now.sys
      success, value = cosmos_script_wait_implementation(target_name, packet_name, item_name, value_type, comparison_to_eval, timeout, polling_rate, scope: scope, token: token)
      time = Time.now.sys - start_time
      wait_str = "WAIT: #{_upcase(target_name, packet_name, item_name)} #{comparison_to_eval}"
      value_str = "with value == #{value} after waiting #{time} seconds"
      if success
        Logger.info "#{wait_str} success #{value_str}"
      else
        Logger.warn "#{wait_str} failed #{value_str}"
      end
    end

    def _wait_tolerance_process_args(args, scope: $cosmos_scope, token: $cosmos_token)
      case args.length
      when 4, 5
        target_name, packet_name, item_name = extract_fields_from_tlm_text(args[0])
        expected_value = args[1]
        if args[2].is_a?(Array)
          tolerance = args[2].map!(&:abs)
        else
          tolerance = args[2].abs
        end
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
        if args[4].is_a?(Array)
          tolerance = args[4].map!(&:abs)
        else
          tolerance = args[4].abs
        end
        timeout = args[5]
        if args.length == 7
          polling_rate = args[6]
        else
          polling_rate = DEFAULT_TLM_POLLING_RATE
        end
      else
        # Invalid number of arguments
        raise "ERROR: Invalid number of arguments (#{args.length}) passed to wait_tolerance()"
      end
      return [target_name, packet_name, item_name, expected_value, tolerance, timeout, polling_rate]
    end

    # When testing an array with a tolerance, the expected value and tolerance
    # can both be supplied as either an array or a single value.  If a single
    # value is passed in, that value will be used for all array elements.
    def array_tolerance_process_args(array_size, expected_value, tolerance, function_name, scope: $cosmos_scope, token: $cosmos_token)
      if expected_value.is_a?(Array)
        if array_size != expected_value.size
          raise "ERROR: Invalid array size for expected_value passed to #{function_name}()"
        end
      else
        expected_value = Array.new(array_size, expected_value)
      end
      if tolerance.is_a?(Array)
        if array_size != tolerance.size
          raise "ERROR: Invalid array size for tolerance passed to #{function_name}()"
        end
      else
        tolerance = Array.new(array_size, tolerance)
      end
      return [expected_value, tolerance]
    end

    def _wait_check_process_args(args, scope: $cosmos_scope, token: $cosmos_token)
      case args.length
      when 2, 3
        target_name, packet_name, item_name, comparison_to_eval = extract_fields_from_check_text(args[0])
        timeout = args[1]
        if args.length == 3
          polling_rate = args[2]
        else
          polling_rate = DEFAULT_TLM_POLLING_RATE
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
      else
        # Invalid number of arguments
        raise "ERROR: Invalid number of arguments (#{args.length}) passed to wait_check()"
      end
      return [target_name, packet_name, item_name, comparison_to_eval, timeout, polling_rate]
    end

    def _cosmos_script_wait_implementation(target_name, packet_name, item_name, value_type, timeout, polling_rate, scope: $cosmos_scope, token: $cosmos_token, &block)
      end_time = Time.now.sys + timeout
      exp_to_eval = yield

      while true
        work_start = Time.now.sys
        value = tlm(target_name, packet_name, item_name, type: value_type, scope: scope, token: token)
        if not block.nil?
          if block.call(value)
            return true, value
          end
        else
          if eval(exp_to_eval)
            return true, value
          end
        end
        break if Time.now.sys >= end_time || $disconnect

        delta = Time.now.sys - work_start
        sleep_time = polling_rate - delta
        end_delta = end_time - Time.now.sys
        sleep_time = end_delta if end_delta < sleep_time
        sleep_time = 0 if sleep_time < 0
        canceled = cosmos_script_sleep(sleep_time)

        if canceled
          value = tlm(target_name, packet_name, item_name, type: value_type, scope: scope, token: token)
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
    def cosmos_script_wait_implementation(target_name, packet_name, item_name, value_type, comparison_to_eval, timeout, polling_rate = DEFAULT_TLM_POLLING_RATE, scope: $cosmos_scope, token: $cosmos_token, &block)
      if comparison_to_eval
        exp_to_eval = "value " + comparison_to_eval
      else
        exp_to_eval = nil
      end
      _cosmos_script_wait_implementation(target_name, packet_name, item_name, value_type, timeout, polling_rate, exp_to_eval, scope: scope, token: token, &block)
    end

    def cosmos_script_wait_implementation_tolerance(target_name, packet_name, item_name, value_type, expected_value, tolerance, timeout, polling_rate = DEFAULT_TLM_POLLING_RATE, scope: $cosmos_scope, token: $cosmos_token, &block)
      exp_to_eval = "((#{expected_value} - #{tolerance})..(#{expected_value} + #{tolerance})).include? value"
      _cosmos_script_wait_implementation(target_name, packet_name, item_name, value_type, timeout, polling_rate, exp_to_eval, scope: scope, token: token, &block)
    end

    def cosmos_script_wait_implementation_array_tolerance(array_size, target_name, packet_name, item_name, value_type, expected_value, tolerance, timeout, polling_rate = DEFAULT_TLM_POLLING_RATE, scope: $cosmos_scope, token: $cosmos_token, &block)
      statements = []
      array_size.times { |i| statements << "(((#{expected_value[i]} - #{tolerance[i]})..(#{expected_value[i]} + #{tolerance[i]})).include? value[#{i}])" }
      exp_to_eval = statements.join(" && ")
      _cosmos_script_wait_implementation(target_name, packet_name, item_name, value_type, timeout, polling_rate, exp_to_eval, scope: scope, token: token, &block)
    end

    # Wait on an expression to be true.
    def cosmos_script_wait_implementation_expression(exp_to_eval, timeout, polling_rate, context, scope: $cosmos_scope, token: $cosmos_token)
      end_time = Time.now.sys + timeout
      # context = ScriptRunnerFrame.instance.script_binding if !context and defined? ScriptRunnerFrame and ScriptRunnerFrame.instance

      while true
        work_start = Time.now.sys
        if eval(exp_to_eval, context)
          return true
        end
        break if Time.now.sys >= end_time

        delta = Time.now.sys - work_start
        sleep_time = polling_rate - delta
        end_delta = end_time - Time.now.sys
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

    def check_eval(target_name, packet_name, item_name, comparison_to_eval, value, scope: $cosmos_scope, token: $cosmos_token)
      string = "value " + comparison_to_eval
      check_str = "CHECK: #{_upcase(target_name, packet_name, item_name)} #{comparison_to_eval}"
      value_str = "with value == #{value}"
      if eval(string)
        Logger.info "#{check_str} success #{value_str}"
      else
        message = "#{check_str} failed #{value_str}"
        if $disconnect
          Logger.error message
        else
          raise CheckError, message
        end
      end
    end
  end
end
