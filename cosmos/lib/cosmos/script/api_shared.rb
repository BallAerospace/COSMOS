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

require 'cosmos/script/extract'

module Cosmos
  module Script
    include Extract

    # Error raised by the API when a check fails
    class CheckError < RuntimeError; end

    DEFAULT_TLM_POLLING_RATE = 0.25

    private
    # Creates a string with the parameters upcased
    def _upcase(target_name, packet_name, item_name)
      "#{target_name.upcase} #{packet_name.upcase} #{item_name.upcase}"
    end

    # Implementaton of the various check commands. It yields back to the
    # caller to allow the return of the value through various telemetry calls.
    # This method should not be called directly by application code.
    def _check(*args, scope: $cosmos_scope, token: $cosmos_token)
      target_name, packet_name, item_name, comparison_to_eval = check_process_args(args, 'check', scope: scope, token: token)

      value = yield(target_name, packet_name, item_name)
      if comparison_to_eval
        check_eval(target_name, packet_name, item_name, comparison_to_eval, value, scope: scope)
      else
        Logger.info "CHECK: #{_upcase(target_name, packet_name, item_name)} == #{value}"
      end
    end

    # Check the converted value of a telmetry item against a condition
    # Always print the value of the telemetry item to STDOUT
    # If the condition check fails, raise an error
    # Supports two signatures:
    # check(target_name, packet_name, item_name, comparison_to_eval)
    # or
    # check('target_name packet_name item_name > 1')
    def check(*args, scope: $cosmos_scope, token: $cosmos_token)
      _check(*args, scope: scope) {|tgt,pkt,item| tlm(tgt,pkt,item,scope: scope,token: token) }
    end

    # Check the formatted value of a telmetry item against a condition
    # Always print the value of the telemetry item to STDOUT
    # If the condition check fails, raise an error
    # Supports two signatures:
    # check(target_name, packet_name, item_name, comparison_to_eval)
    # or
    # check('target_name packet_name item_name > 1')
    def check_formatted(*args, scope: $cosmos_scope, token: $cosmos_token)
      _check(*args, scope: scope) {|tgt,pkt,item| tlm_formatted(tgt,pkt,item,scope: scope,token: token) }
    end

    # Check the formatted with units value of a telmetry item against a condition
    # Always print the value of the telemetry item to STDOUT
    # If the condition check fails, raise an error
    # Supports two signatures:
    # check(target_name, packet_name, item_name, comparison_to_eval)
    # or
    # check('target_name packet_name item_name > 1')
    def check_with_units(*args, scope: $cosmos_scope, token: $cosmos_token)
      _check(*args, scope: scope) {|tgt,pkt,item| tlm_with_units(tgt,pkt,item,scope: scope,token: token) }
    end

    # Check the raw value of a telmetry item against a condition
    # Always print the value of the telemetry item to STDOUT
    # If the condition check fails, raise an error
    # Supports two signatures:
    # check(target_name, packet_name, item_name, comparison_to_eval)
    # or
    # check('target_name packet_name item_name > 1')
    def check_raw(*args, scope: $cosmos_scope, token: $cosmos_token)
      _check(*args, scope: scope) {|tgt,pkt,item| tlm_raw(tgt,pkt,item,scope: scope, token: token) }
    end

    # Executes the passed method and expects an exception to be raised.
    # Raises a CheckError if an Exception is not raised.
    # Usage:
    #   check_exception(method_name, method_params}
    def check_exception(method_name, *method_params, scope: $cosmos_scope, token: $cosmos_token)
      send(method_name, *method_params, scope: scope, token: token)
    rescue Exception => error
      Logger.info "CHECK: #{method_name}(#{method_params.join(", ")}) raised #{error.class}:#{error.message}"
    else
      raise(CheckError, "#{method_name}(#{method_params.join(", ")}) should have raised an exception but did not.")
    end

    def _check_tolerance(*args, scope: $cosmos_scope, token: $cosmos_token)
      target_name, packet_name, item_name, expected_value, tolerance =
        check_tolerance_process_args(args, 'check_tolerance', scope: scope, token: token)
      value = yield(target_name, packet_name, item_name)
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

    # Check the converted value of a telmetry item against an expected value with a tolerance
    # Always print the value of the telemetry item to STDOUT
    # If the condition check fails, raise an error
    # Supports two signatures:
    # check_tolerance(target_name, packet_name, item_name, expected_value, tolerance)
    # or
    # check_tolerance('target_name packet_name item_name', expected_value, tolerance)
    def check_tolerance(*args, scope: $cosmos_scope, token: $cosmos_token)
      _check_tolerance(*args, scope: scope) {|tgt,pkt,item| tlm(tgt,pkt,item, scope: scope, token: token) }
    end

    # Check the raw value of a telmetry item against an expected value with a tolerance
    # Always print the value of the telemetry item to STDOUT
    # If the condition check fails, raise an error
    # Supports two signatures:
    # check_tolerance_raw(target_name, packet_name, item_name, expected_value, tolerance)
    # or
    # check_tolerance_raw('target_name packet_name item_name', expected_value, tolerance)
    def check_tolerance_raw(*args, scope: $cosmos_scope, token: $cosmos_token)
      _check_tolerance(*args, scope: scope) {|tgt,pkt,item| tlm_raw(tgt,pkt,item, scope: scope, token: token) }
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

    # Wait on an expression to be true.  On a timeout, the script will continue.
    # Supports multiple signatures:
    # wait(time)
    # wait('target_name packet_name item_name > 1', timeout, polling_rate)
    # wait('target_name', 'packet_name', 'item_name', comparison_to_eval, timeout, polling_rate)
    def wait(*args, scope: $cosmos_scope, token: $cosmos_token)
      wait_process_args(args, 'wait', :CONVERTED, scope: scope, token: token)
    end

    # Wait on an expression to be true.  On a timeout, the script will continue.
    # Supports multiple signatures:
    # wait(time)
    # wait_raw('target_name packet_name item_name > 1', timeout, polling_rate)
    # wait_raw('target_name', 'packet_name', 'item_name', comparison_to_eval, timeout, polling_rate)
    def wait_raw(*args, scope: $cosmos_scope, token: $cosmos_token)
      wait_process_args(args, 'wait_raw', :RAW, scope: scope, token: token)
    end

    def _wait_tolerance(raw, *args, scope: $cosmos_scope, token: $cosmos_token)
      type = (raw ? :RAW : :CONVERTED)
      type_string = 'wait_tolerance'
      type_string << '_raw' if raw
      target_name, packet_name, item_name, expected_value, tolerance, timeout, polling_rate = wait_tolerance_process_args(args, type_string, scope: scope, token: token)
      start_time = Time.now.sys
      value = tlm_variable(target_name, packet_name, item_name, type, scope: scope, token: token)
      if value.is_a?(Array)
        expected_value, tolerance = array_tolerance_process_args(value.size, expected_value, tolerance, type_string, scope: scope, token: token)

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

    # Wait on an expression to be true.  On a timeout, the script will continue.
    # Supports multiple signatures:
    # wait_tolerance('target_name packet_name item_name', expected_value, tolerance, timeout, polling_rate)
    # wait_tolerance('target_name', 'packet_name', 'item_name', expected_value, tolerance, timeout, polling_rate)
    def wait_tolerance(*args, scope: $cosmos_scope, token: $cosmos_token)
      _wait_tolerance(false, *args, scope: scope, token: token)
    end

    # Wait on an expression to be true.  On a timeout, the script will continue.
    # Supports multiple signatures:
    # wait_tolerance_raw('target_name packet_name item_name', expected_value, tolerance, timeout, polling_rate)
    # wait_tolerance_raw('target_name', 'packet_name', 'item_name', expected_value, tolerance, timeout, polling_rate)
    def wait_tolerance_raw(*args, scope: $cosmos_scope, token: $cosmos_token)
      _wait_tolerance(true, *args, scope: scope, token: token)
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

    def _wait_check(raw, *args, scope: $cosmos_scope, token: $cosmos_token)
      type = (raw ? :RAW : :CONVERTED)
      target_name, packet_name, item_name, comparison_to_eval, timeout, polling_rate = wait_check_process_args(args, 'wait_check', scope: scope, token: token)
      start_time = Time.now.sys
      success, value = cosmos_script_wait_implementation(target_name, packet_name, item_name, type, comparison_to_eval, timeout, polling_rate, scope: scope, token: token)
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

    # Wait for the converted value of a telmetry item against a condition or for a timeout
    # and then check against the condition
    # Supports two signatures:
    # wait_check(target_name, packet_name, item_name, comparison_to_eval, timeout, polling_rate)
    # or
    # wait_check('target_name packet_name item_name > 1', timeout, polling_rate)
    def wait_check(*args, scope: $cosmos_scope, token: $cosmos_token)
      _wait_check(false, *args, scope: scope, token: token)
    end

    # Wait for the raw value of a telmetry item against a condition or for a timeout
    # and then check against the condition
    # Supports two signatures:
    # wait_check_raw(target_name, packet_name, item_name, comparison_to_eval, timeout, polling_rate)
    # or
    # wait_check_raw('target_name packet_name item_name > 1', timeout, polling_rate)
    def wait_check_raw(*args, scope: $cosmos_scope, token: $cosmos_token)
      _wait_check(true, *args, scope: scope, token: token)
    end

    def _wait_check_tolerance(raw, *args, scope: $cosmos_scope, token: $cosmos_token)
      type_string = 'wait_check_tolerance'
      type_string << '_raw' if raw
      type = (raw ? :RAW : :CONVERTED)
      target_name, packet_name, item_name, expected_value, tolerance, timeout, polling_rate = wait_tolerance_process_args(args, type_string, scope: scope, token: token)
      start_time = Time.now.sys
      value = tlm_variable(target_name, packet_name, item_name, type, scope: scope, token: token)
      if value.is_a?(Array)
        expected_value, tolerance = array_tolerance_process_args(value.size, expected_value, tolerance, type_string, scope: scope, token: token)

        success, value = cosmos_script_wait_implementation_array_tolerance(value.size, target_name, packet_name, item_name, type, expected_value, tolerance, timeout, polling_rate, scope: scope, token: token)
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

    def wait_check_tolerance(*args, scope: $cosmos_scope, token: $cosmos_token)
      _wait_check_tolerance(false, *args, scope: scope, token: token)
    end

    def wait_check_tolerance_raw(*args, scope: $cosmos_scope, token: $cosmos_token)
      _wait_check_tolerance(true, *args, scope: scope, token: token)
    end

    # Wait on an expression to be true.  On a timeout, the script will pause.
    def wait_check_expression(exp_to_eval,
                              timeout,
                              polling_rate = DEFAULT_TLM_POLLING_RATE,
                              context = nil,
                              scope: $cosmos_scope, token: $cosmos_token)
      start_time = Time.now.sys
      success = cosmos_script_wait_implementation_expression(exp_to_eval,
                                                             timeout,
                                                             polling_rate,
                                                             context, scope: scope, token: token)
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
                                                         token: token
                                                      )
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

    def _get_procedure_path(procedure_name)
      # Handle not-giving an extension
      procedure_name_with_extension = nil
      procedure_name_with_extension = procedure_name + '.rb' if File.extname(procedure_name).empty?

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

      raise LoadError, "Procedure not found -- #{procedure_name}" unless path
      path
    end

    def check_file_cache_for_instrumented_script(path, hash_string)
      file_text = nil
      instrumented_script = nil
      cached = true
      # use_file_cache = true

      # TODO
      # Cosmos.set_working_dir do
      #   cache_path = File.join(System.paths['TMP'], 'script_runner')
      #   unless File.directory?(cache_path)
      #     # Try to create .cache directory
      #     begin
      #       Dir.mkdir(cache_path)
      #     rescue
      #       use_file_cache = false
      #     end
      #   end

      #   cache_filename = nil
      #   if use_file_cache
      #     # Check file based instrumented cache
      #     flat_path = path.tr("/", "_").gsub("\\", "_").tr(":", "_").tr(" ", "_")
      #     flat_path_with_hash_string = flat_path + '_' + hash_string
      #     cache_filename = File.join(cache_path, flat_path_with_hash_string)
      #   end

      #   begin
      #     file_text = File.read(path)
      #   rescue Exception => error
      #     msg = "Error reading procedure file '#{path}' due to #{error.message}."
      #     raise $!, msg, $!.backtrace
      #   end

      #   if use_file_cache and File.exist?(cache_filename)
      #     # Use file cached instrumentation
      #     File.open(cache_filename, 'r') {|file| instrumented_script = file.read}
      #   else
      #     cached = false

      #     # Build instrumentation
      #     instrumented_script = ScriptRunnerFrame.instrument_script(file_text, path, true)

      #     # Cache instrumentation into file
      #     if use_file_cache
      #       begin
      #         File.open(cache_filename, 'w') {|file| file.write(instrumented_script)}
      #       rescue
      #         # Oh well, failed to write cache file
      #       end
      #     end
      #   end
      # end
      [file_text, instrumented_script, cached]
    end

    def start(procedure_name)
      raise "TODO: start needs to be updated"
      # cached = true
      # path = _get_procedure_path(procedure_name)

      # if defined? ScriptRunnerFrame and ScriptRunnerFrame.instance
      #   hashing_sum = nil
      #   begin
      #     hashing_result = Cosmos.hash_files([path], nil, System.hashing_algorithm)
      #     hash_string = hashing_result.hexdigest
      #     # Only use at most, 32 characters of the hex
      #     hash_string = hash_string[-32..-1] if hash_string.length >= 32
      #   rescue Exception => error
      #     raise "Error calculating hash string on procedure file : #{path}"
      #   end

      #   # Check RAM based instrumented cache
      #   instrumented_cache = ScriptRunnerFrame.instrumented_cache[path]
      #   instrumented_script = nil
      #   if instrumented_cache and hash_string == instrumented_cache[1]
      #     # Use cached instrumentation
      #     instrumented_script = instrumented_cache[0]
      #   else
      #     file_text, instrumented_script, cached = check_file_cache_for_instrumented_script(path, hash_string)
      #     # Cache instrumentation into RAM
      #     ScriptRunnerFrame.file_cache[path] = file_text
      #     ScriptRunnerFrame.instrumented_cache[path] = [instrumented_script, hash_string]
      #   end

      #   Object.class_eval(instrumented_script, path, 1)
      # else # No ScriptRunnerFrame so just start it locally
      #   cached = false
      #   begin
      #     Kernel::load(path)
      #   rescue LoadError => error
      #     raise LoadError, "Error loading -- #{procedure_name}\n#{error.message}"
      #   end
      # end
      # # Return whether we had to load and instrument this file, i.e. it was not cached
      # !cached
    end

    # Require an additional ruby file
    def load_utility(procedure_name)
      # TODO
      not_cached = false
      # if defined? ScriptRunnerFrame and ScriptRunnerFrame.instance
      #   saved = ScriptRunnerFrame.instance.use_instrumentation
      #   begin
      #     ScriptRunnerFrame.instance.use_instrumentation = false
      #     not_cached = start(procedure_name)
      #   ensure
      #     ScriptRunnerFrame.instance.use_instrumentation = saved
      #   end
      # else # Just call start
      not_cached = start(procedure_name)
      # end
      # Return whether we had to load and instrument this file, i.e. it was not cached
      # This is designed to match the behavior of Ruby's require and load keywords
      not_cached
    end
    alias require_utility load_utility

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

    ##########################################
    # Protected Methods
    ##########################################

    def check_process_args(args, function_name, scope: $cosmos_scope, token: $cosmos_token)
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

    def check_tolerance_process_args(args, function_name, scope: $cosmos_scope, token: $cosmos_token)
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
        raise "ERROR: Invalid number of arguments (#{args.length}) passed to #{function_name}()"
      end
      return [target_name, packet_name, item_name, expected_value, tolerance]
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

    def wait_process_args(args, function_name, value_type, scope: $cosmos_scope, token: $cosmos_token)
      time = nil

      case args.length
      when 0
        start_time = Time.now.sys
        cosmos_script_sleep()
        time = Time.now.sys - start_time
        Logger.info("WAIT: Indefinite for actual time of #{time} seconds")
      when 1
        if args[0].kind_of? Numeric
          start_time = Time.now.sys
          cosmos_script_sleep(args[0])
          time = Time.now.sys - start_time
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
        _execute_wait(target_name, packet_name, item_name, value_type, comparison_to_eval, timeout, polling_rate, scope: scope, token: token)

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
        _execute_wait(target_name, packet_name, item_name, value_type, comparison_to_eval, timeout, polling_rate, scope: scope, token: token)

      else
        # Invalid number of arguments
        raise "ERROR: Invalid number of arguments (#{args.length}) passed to #{function_name}()"
      end
      time
    end

    def wait_tolerance_process_args(args, function_name, scope: $cosmos_scope, token: $cosmos_token)
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
        raise "ERROR: Invalid number of arguments (#{args.length}) passed to #{function_name}()"
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

    def wait_check_process_args(args, function_name, scope: $cosmos_scope, token: $cosmos_token)
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
        raise "ERROR: Invalid number of arguments (#{args.length}) passed to #{function_name}()"
      end
      return [target_name, packet_name, item_name, comparison_to_eval, timeout, polling_rate]
    end

    def _cosmos_script_wait_implementation(target_name, packet_name, item_name, value_type, timeout, polling_rate, scope: $cosmos_scope, token: $cosmos_token)
      end_time = Time.now.sys + timeout
      exp_to_eval = yield

      while true
        work_start = Time.now.sys
        value = tlm_variable(target_name, packet_name, item_name, value_type, scope: scope, token: token)
        if eval(exp_to_eval)
          return true, value
        end
        break if Time.now.sys >= end_time || $disconnect

        delta = Time.now.sys - work_start
        sleep_time = polling_rate - delta
        end_delta = end_time - Time.now.sys
        sleep_time = end_delta if end_delta < sleep_time
        sleep_time = 0 if sleep_time < 0
        canceled = cosmos_script_sleep(sleep_time)

        if canceled
          value = tlm_variable(target_name, packet_name, item_name, value_type, scope: scope, token: token)
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
    def cosmos_script_wait_implementation(target_name, packet_name, item_name, value_type, comparison_to_eval, timeout, polling_rate = DEFAULT_TLM_POLLING_RATE, scope: $cosmos_scope, token: $cosmos_token)
      _cosmos_script_wait_implementation(target_name, packet_name, item_name, value_type, timeout, polling_rate, scope: scope, token: token) do
        "value " + comparison_to_eval
      end
    end

    def cosmos_script_wait_implementation_tolerance(target_name, packet_name, item_name, value_type, expected_value, tolerance, timeout, polling_rate = DEFAULT_TLM_POLLING_RATE, scope: $cosmos_scope, token: $cosmos_token)
      _cosmos_script_wait_implementation(target_name, packet_name, item_name, value_type, timeout, polling_rate, scope: scope, token: token) do
        "((#{expected_value} - #{tolerance})..(#{expected_value} + #{tolerance})).include? value"
      end
    end

    def cosmos_script_wait_implementation_array_tolerance(array_size, target_name, packet_name, item_name, value_type, expected_value, tolerance, timeout, polling_rate = DEFAULT_TLM_POLLING_RATE, scope: $cosmos_scope, token: $cosmos_token)
      statements = []
      array_size.times {|i| statements << "(((#{expected_value[i]} - #{tolerance[i]})..(#{expected_value[i]} + #{tolerance[i]})).include? value[#{i}])"}
      exp_to_eval = statements.join(" && ")
      _cosmos_script_wait_implementation(target_name, packet_name, item_name, value_type, timeout, polling_rate, scope: scope, token: token) do
        exp_to_eval
      end
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

    #######################################
    # Methods accessing tlm_viewer
    #######################################

    def display(display_name, x_pos = nil, y_pos = nil)
      # TODO
      # run_tlm_viewer("display", display_name) do |tlm_viewer|
      #  tlm_viewer.display(display_name, x_pos, y_pos)
      # end
    end

    def clear(display_name)
      # TODO
      # run_tlm_viewer("clear", display_name) do |tlm_viewer|
      #  tlm_viewer.clear(display_name)
      # end
    end

    def clear_all(target = nil)
      # TODO
      # run_tlm_viewer("clear_all") do |tlm_viewer|
      #  tlm_viewer.clear_all(target)
      # end
    end
  end
end
