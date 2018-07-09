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

    #######################################
    # Methods accessing script runner
    #######################################

    def _ensure_script_runner_frame
      yield if (defined? ScriptRunnerFrame) && ScriptRunnerFrame.instance
    end

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
      _ensure_script_runner_frame do
        filename = ScriptRunnerFrame.instance.message_log.filename if ScriptRunnerFrame.instance.message_log
      end
      return filename
    end

    def start_new_scriptrunner_message_log
      # A new log will be created at the next message
      _ensure_script_runner_frame { ScriptRunnerFrame.instance.stop_message_log }
    end

    def disable_instrumentation
      if (defined? ScriptRunnerFrame) && ScriptRunnerFrame.instance
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
      _ensure_script_runner_frame { ScriptRunnerFrame.instance.stdout_max_lines = max_lines }
    end

    #######################################
    # Methods for debugging
    #######################################

    def insert_return(*params)
      _ensure_script_runner_frame do
        ScriptRunnerFrame.instance.inline_return = true
        ScriptRunnerFrame.instance.inline_return_params = params
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

    ###########################
    # Telemetry Screen methods
    ###########################

    # Get the organized list of available telemetry screens
    def get_screen_list(config_filename = nil, force_refresh = false)
      $cmd_tlm_server.get_screen_list(config_filename, force_refresh)
    end

    # Get a specific screen definition
    def get_screen_definition(screen_full_name, config_filename = nil, force_refresh = false)
      $cmd_tlm_server.get_screen_definition(screen_full_name, config_filename, force_refresh)
    end

    # Show a local telemetry screen
    def local_screen(title = 'Local Screen', screen_def = nil, x_pos = nil, y_pos = nil, &block)
      # See script_module_gui.rb
    end

    # Close all local telemetry screens
    def close_local_screens
      # See script_module_gui.rb
    end

  end # module Script

end # module Cosmos
