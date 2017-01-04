# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/script/extract'

module Cosmos
  module Script
    DEFAULT_TLM_POLLING_RATE = 0.25

    private
    # Include various methods to extract fields from text
    include Extract

    def play_wav_file(wav_filename)
      Cosmos.play_wav_file(wav_filename)
    end

    def status_bar(message)
      if defined? ScriptRunner
        script_runner = nil
        ObjectSpace.each_object {|object| if ScriptRunner === object then script_runner = object; break; end}
        script_runner.script_set_status(message) if script_runner
      end
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

    def vertical_message_box(string, *buttons)
      prompt_vertical_message_box(string, buttons)
    end

    def combo_box(string, *options)
      prompt_combo_box(string, options)
    end

    def _file_dialog(message, directory, select_files = true)
      answer = ''
      files = Dir["#{directory}/*"]
      if select_files
        files.select! {|f| !File.directory? f }
      else
        files.select! {|f| File.directory? f }
      end
      while answer.empty?
        print message + "\n" + files.join("\n") + "\n<Type file name>:"
        answer = gets
        answer.chomp!
      end
      return answer
    end
    def save_file_dialog(directory = Cosmos::USERPATH, message = "Save File")
      _file_dialog(message, directory)
    end
    def open_file_dialog(directory = Cosmos::USERPATH, message = "Open File")
      _file_dialog(message, directory)
    end
    def open_files_dialog(directory = Cosmos::USERPATH, message = "Open File(s)")
      _file_dialog(message, directory)
    end
    def open_directory_dialog(directory = Cosmos::USERPATH, message = "Open Directory")
      _file_dialog(message, directory, false)
    end

    # Creates a string with the parameters upcased
    def _upcase(target_name, packet_name, item_name)
      "#{target_name.upcase} #{packet_name.upcase} #{item_name.upcase}"
    end

    # Implementaiton of the various check commands. It yields back to the
    # caller to allow the return of the value through various telemetry calls.
    # This method should not be called directly by application code.
    def _check(*args)
      target_name, packet_name, item_name, comparison_to_eval = check_process_args(args, 'check')
      value = yield(target_name, packet_name, item_name)
      if comparison_to_eval
        check_eval(target_name, packet_name, item_name, comparison_to_eval, value)
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
      check_str = "CHECK: #{_upcase(target_name, packet_name, item_name)}"
      range_str = "range #{range.first} to #{range.last} with value == #{value}"
      if range.include?(value)
        Logger.info "#{check_str} was within #{range_str}"
      else
        message = "#{check_str} failed to be within #{range_str}"
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
      wait_str = "WAIT: #{_upcase(target_name, packet_name, item_name)}"
      range_str = "range #{range.first} to #{range.last} with value == #{value} after waiting #{time} seconds"
      if success
        Logger.info "#{wait_str} was within #{range_str}"
      else
        Logger.warn "#{wait_str} failed to be within #{range_str}"
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
      check_str = "CHECK: #{_upcase(target_name, packet_name, item_name)} #{comparison_to_eval}"
      with_value_str = "with value == #{value} after waiting #{time} seconds"
      if success
        Logger.info "#{check_str} success #{with_value_str}"
      else
        message = "#{check_str} failed #{with_value_str}"
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
      check_str = "CHECK: #{_upcase(target_name, packet_name, item_name)}"
      range_str = "range #{range.first} to #{range.last} with value == #{value} after waiting #{time} seconds"
      if success
        Logger.info "#{check_str} was within #{range_str}"
      else
        message = "#{check_str} failed to be within #{range_str}"
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

    def check_file_cache_for_instrumented_script(path, md5)
      instrumented_script = nil
      cached = true
      use_file_cache = true

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

        cache_filename = nil
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
          cached = false

          # Build instrumentation
          file_text = ''
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
      [instrumented_script, cached]
    end

    def start(procedure_name)
      cached = true
      path = _get_procedure_path(procedure_name)

      if defined? ScriptRunnerFrame and ScriptRunnerFrame.instance
        md5 = nil
        begin
          md5 = Cosmos.md5_files([path]).hexdigest
        rescue Exception => error
          raise "Error calculating md5 on procedure file : #{path}"
        end

        # Check RAM based instrumented cache
        instrumented_cache = ScriptRunnerFrame.instrumented_cache[path]
        instrumented_script = nil
        if instrumented_cache and md5 == instrumented_cache[1]
          # Use cached instrumentation
          instrumented_script = instrumented_cache[0]
        else
          instrumented_script, cached = check_file_cache_for_instrumented_script(path, md5)
          # Cache instrumentation into RAM
          ScriptRunnerFrame.instrumented_cache[path] = [instrumented_script, md5]
        end

        Object.class_eval(instrumented_script, path, 1)
      else # No ScriptRunnerFrame so just start it locally
        cached = false
        begin
          Kernel::load(path)
        rescue LoadError => error
          raise LoadError, "Error loading -- #{procedure_name}\n#{error.message}"
        end
      end
      # Return whether we had to load and instrument this file, i.e. it was not cached
      !cached
    end

    # Require an additional ruby file
    def load_utility(procedure_name)
      not_cached = false
      if defined? ScriptRunnerFrame and ScriptRunnerFrame.instance
        saved = ScriptRunnerFrame.instance.use_instrumentation
        begin
          ScriptRunnerFrame.instance.use_instrumentation = false
          not_cached = start(procedure_name)
        ensure
          ScriptRunnerFrame.instance.use_instrumentation = saved
        end
      else # Just call start
        not_cached = start(procedure_name)
      end
      # Return whether we had to load and instrument this file, i.e. it was not cached
      # This is designed to match the behavior of Ruby's require and load keywords
      not_cached
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
        tolerance = args[2].abs
      when 5
        target_name = args[0]
        packet_name = args[1]
        item_name = args[2]
        expected_value = args[3]
        tolerance = args[4].abs
      else
        # Invalid number of arguments
        raise "ERROR: Invalid number of arguments (#{args.length}) passed to #{function_name}()"
      end
      return [target_name, packet_name, item_name, expected_value, tolerance]
    end

    def _execute_wait(target_name, packet_name, item_name, value_type, comparison_to_eval, timeout, polling_rate)
      start_time = Time.now
      success, value = cosmos_script_wait_implementation(target_name, packet_name, item_name, value_type, comparison_to_eval, timeout, polling_rate)
      time = Time.now - start_time
      wait_str = "WAIT: #{_upcase(target_name, packet_name, item_name)} #{comparison_to_eval}"
      value_str = "with value == #{value} after waiting #{time} seconds"
      if success
        Logger.info "#{wait_str} success #{value_str}"
      else
        Logger.warn "#{wait_str} failed #{value_str}"
      end
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
        _execute_wait(target_name, packet_name, item_name, value_type, comparison_to_eval, timeout, polling_rate)

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
        _execute_wait(target_name, packet_name, item_name, value_type, comparison_to_eval, timeout, polling_rate)

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
        tolerance = args[2].abs
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
        tolerance = args[4].abs
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
        "((#{expected_value} - #{tolerance.abs})..(#{expected_value} + #{tolerance.abs})).include? value"
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
      check_str = "CHECK: #{_upcase(target_name, packet_name, item_name)} #{comparison_to_eval}"
      value_str = "with value == #{value}"
      if eval(string)
        Logger.info "#{check_str} success #{value_str}"
      else
        message = "#{check_str} failed #{value_str}"
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

    def prompt_vertical_message_box(string, options)
      prompt_message_box(string, options)
    end

    def prompt_combo_box(string, options)
      prompt_message_box(string, options)
    end

  end # module Script

end # module Cosmos
