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
    # Methods accessing tlm_viewer
    #######################################

    def display(display_name, x_pos = nil, y_pos = nil)
      run_tlm_viewer(display_name, "displayed") do |tlm_viewer|
        tlm_viewer.display(display_name, x_pos, y_pos)
      end
    end

    def clear(display_name)
      run_tlm_viewer(display_name, "cleared") do |tlm_viewer|
        tlm_viewer.clear(display_name)
      end
    end

    def run_tlm_viewer(display_name, action)
      tlm_viewer = JsonDRbObject.new "localhost", System.ports['TLMVIEWER_API']
      begin
        yield tlm_viewer
        tlm_viewer.disconnect
      rescue DRb::DRbConnError
        # No Listening Tlm Viewer - So Start One
        start_tlm_viewer
        max_retries = 60
        retry_count = 0
        begin
          yield tlm_viewer
          tlm_viewer.disconnect
        rescue DRb::DRbConnError
          retry_count += 1
          if retry_count < max_retries
            canceled = cosmos_script_sleep(1)
            retry unless canceled
          end
          raise "Unable to Successfully Start Listening Telemetry Viewer: #{display_name} could not be #{action}"
        rescue Errno::ENOENT
          raise "Display Screen File: #{display_name}.txt does not exist"
        end
      rescue Errno::ENOENT
        raise "Display Screen File: #{display_name}.txt does not exist"
      end
    end

    def start_tlm_viewer
      system_file = File.basename(System.initial_filename)
      mac_app = File.join(Cosmos::USERPATH, 'tools', 'mac', 'TlmViewer.app')

      if Kernel.is_mac? && File.exist?(mac_app)
        Cosmos.run_process("open '#{mac_app}' --args --system #{system_file}")
      else
        cmd = 'ruby'
        cmd << 'w' if Kernel.is_windows? # Windows uses rubyw to avoid creating a DOS shell
        Cosmos.run_process("#{cmd} '#{File.join(Cosmos::USERPATH, 'tools', 'TlmViewer')}' --system #{system_file}")
      end
      cosmos_script_sleep(1)
    end

    #######################################
    # Methods accessing script runner
    #######################################

    def _ensure_script_runner_frame
      yield if (defined? ScriptRunnerFrame) && ScriptRunnerFrame.instance
    end

    def set_line_delay(delay)
      _ensure_script_runner_frame { ScriptRunnerFrame.line_delay = delay if delay >= 0.0 }
    end

    def get_line_delay
      _ensure_script_runner_frame { ScriptRunnerFrame.line_delay }
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
      _ensure_script_runner_frame { ScriptRunnerFrame.step_mode = true }
    end

    def run_mode
      _ensure_script_runner_frame { ScriptRunnerFrame.step_mode = false }
    end

    def show_backtrace(value = true)
      _ensure_script_runner_frame { ScriptRunnerFrame.show_backtrace = value }
    end

  end # module Script

end # module Cosmos
