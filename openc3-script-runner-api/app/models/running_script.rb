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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'json'
require 'securerandom'
require 'thread'
require 'openc3'
require 'openc3/utilities/s3'
require 'openc3/script'
require 'openc3/io/stdout'
require 'openc3/io/stderr'
require 'childprocess'
require 'openc3/script/suite_runner'
require 'openc3/utilities/store'

RAILS_ROOT = File.expand_path(File.join(__dir__, '..', '..'))

module OpenC3
  module Script
    private
    # Define all the user input methods used in scripting which we need to broadcast to the frontend
    # Note: This list matches the list in run_script.rb:112
    SCRIPT_METHODS = %i[ask ask_string message_box vertical_message_box combo_box prompt prompt_for_hazardous
       input_metadata open_file_dialog open_files_dialog]
    SCRIPT_METHODS.each do |method|
      define_method(method) do |*args, **kwargs|
        while true
          if RunningScript.instance
            RunningScript.instance.scriptrunner_puts("#{method}(#{args.join(', ')})")
            prompt_id = SecureRandom.uuid
            RunningScript.instance.perform_wait({ 'method' => method, 'id' => prompt_id, 'args' => args, 'kwargs' => kwargs })
            input = RunningScript.instance.user_input
            # All ask and prompt dialogs should include a 'Cancel' button
            # If they cancel we wait so they can potentially stop
            if input == 'Cancel'
              RunningScript.instance.perform_pause
            else
              if (method.to_s.include?('open_file'))
                files = input.map { |file| _get_storage_file("tmp/#{file}", scope: RunningScript.instance.scope) }
                files = files[0] if method.to_s == 'open_file_dialog' # Simply return the only file
                return files
              else
                return input
              end
            end
          else
            raise "Script input method called outside of running script"
          end
        end
      end
    end

    OpenC3.disable_warnings do
      def load_s3(*args, **kw_args)
        path = args[0]

        # Only support TARGET files
        if path[0] == '/' or path.split('/')[0].to_s.upcase != path.split('/')[0]
          raise LoadError
        end
        extension = File.extname(path)
        path = path + '.rb' if extension == ""

        # Retrieve the text of the script from S3
        if RunningScript.instance
          scope = RunningScript.instance.scope
        else
          scope = $openc3_scope
        end
        text = ::Script.body(scope, path)

        # Execute the script directly without instrumentation because we are doing require/load
        Object.class_eval(text, path, 1)

        # Successful load/require returns true
        true
      end

      def require(*args, **kw_args)
        begin
          super(*args, **kw_args)
        rescue LoadError
          begin
            load_s3(*args, **kw_args)
          rescue Exception
            raise LoadError
          end
        end
      end

      def load(*args, **kw_args)
        begin
          super(*args, **kw_args)
        rescue LoadError
          begin
            load_s3(*args, **kw_args)
          rescue Exception
            raise LoadError
          end
        end
      end

      def start(procedure_name)
        path = procedure_name

        # Check RAM based instrumented cache
        breakpoints = RunningScript.breakpoints[path]&.filter { |_, present| present }&.map { |line_number, _| line_number - 1 } # -1 because frontend lines are 0-indexed
        breakpoints ||= []
        instrumented_cache, text = RunningScript.instrumented_cache[path]
        instrumented_script = nil
        if instrumented_cache
          # Use cached instrumentation
          instrumented_script = instrumented_cache
          cached = true
          OpenC3::Store.publish(["script-api", "running-script-channel:#{RunningScript.instance.id}"].compact.join(":"), JSON.generate({ type: :file, filename: procedure_name, text: text, breakpoints: breakpoints }))
        else
          # Retrieve file
          text = ::Script.body(RunningScript.instance.scope, procedure_name)
          OpenC3::Store.publish(["script-api", "running-script-channel:#{RunningScript.instance.id}"].compact.join(":"), JSON.generate({ type: :file, filename: procedure_name, text: text, breakpoints: breakpoints }))

          # Cache instrumentation into RAM
          instrumented_script = RunningScript.instrument_script(text, path, true)
          RunningScript.instrumented_cache[path] = [instrumented_script, text]
          cached = false
        end

        Object.class_eval(instrumented_script, path, 1)

        # Return whether we had to load and instrument this file, i.e. it was not cached
        !cached
      end

      # Require an additional ruby file
      def load_utility(procedure_name)
        not_cached = false
        if defined? RunningScript and RunningScript.instance
          saved = RunningScript.instance.use_instrumentation
          begin
            RunningScript.instance.use_instrumentation = false
            not_cached = start(procedure_name)
          ensure
            RunningScript.instance.use_instrumentation = saved
          end
        else # Just call require
          not_cached = require(procedure_name)
        end
        # Return whether we had to load and instrument this file, i.e. it was not cached
        # This is designed to match the behavior of Ruby's require and load keywords
        not_cached
      end
      alias require_utility load_utility

      # sleep in a script - returns true if canceled mid sleep
      def openc3_script_sleep(sleep_time = nil)
        return true if $disconnect
        OpenC3::Store.publish(["script-api", "running-script-channel:#{RunningScript.instance.id}"].compact.join(":"), JSON.generate({ type: :line, filename: RunningScript.instance.current_filename, line_no: RunningScript.instance.current_line_number, state: :waiting }))

        sleep_time = 30000000 unless sleep_time # Handle infinite wait
        if sleep_time > 0.0
          end_time = Time.now.sys + sleep_time
          count = 0
          until Time.now.sys >= end_time
            sleep(0.01)
            count += 1
            if (count % 100) == 0 # Approximately Every Second
              OpenC3::Store.publish(["script-api", "running-script-channel:#{RunningScript.instance.id}"].compact.join(":"), JSON.generate({ type: :line, filename: RunningScript.instance.current_filename, line_no: RunningScript.instance.current_line_number, state: :waiting }))
            end
            if RunningScript.instance.pause?
              RunningScript.instance.perform_pause
              return true
            end
            return true if RunningScript.instance.go?
            raise StopScript if RunningScript.instance.stop?
          end
        end
        return false
      end
    end
  end
end

class RunningScript
  attr_accessor :id
  attr_accessor :state
  attr_accessor :scope
  attr_accessor :name

  attr_accessor :use_instrumentation
  # TODO: Why are there both filename and current_filename
  attr_reader :filename
  attr_reader :current_filename
  attr_reader :current_line_number
  attr_accessor :continue_after_error
  attr_accessor :exceptions
  attr_accessor :script_binding
  attr_reader :script_class
  attr_reader :top_level_instrumented_cache
  attr_accessor :stdout_max_lines
  attr_reader :script
  attr_accessor :user_input
  attr_accessor :prompt_id

  @@instance = nil
  @@id = nil
  @@message_log = nil
  @@run_thread = nil
  @@breakpoints = {}
  @@line_delay = 0.1
  @@instrumented_cache = {}
  @@file_cache = {}
  @@output_thread = nil
  @@limits_monitor_thread = nil
  @@pause_on_error = true
  @@monitor_limits = false
  @@pause_on_red = false
  @@show_backtrace = false
  @@error = nil
  @@output_sleeper = OpenC3::Sleeper.new
  @@limits_sleeper = OpenC3::Sleeper.new
  @@cancel_output = false
  @@cancel_limits = false

  def self.message_log(id = @@id)
    unless @@message_log
      if @@instance
        @@message_log = OpenC3::MessageLog.new("sr", File.join(RAILS_ROOT, 'log'), scope: @@instance.scope)
      else
        @@message_log = OpenC3::MessageLog.new("sr", File.join(RAILS_ROOT, 'log'), scope: $openc3_scope)
      end
    end
    return @@message_log
  end

  def message_log
    self.class.message_log(@id)
  end

  def self.all
    array = OpenC3::Store.smembers('running-scripts')
    items = []
    array.each do |member|
      items << JSON.parse(member, :allow_nan => true, :create_additions => true)
    end
    items.sort { |a, b| b['id'] <=> a['id'] }
  end

  def self.find(id)
    result = OpenC3::Store.get("running-script:#{id}").to_s
    if result.length > 0
      JSON.parse(result, :allow_nan => true, :create_additions => true)
    else
      return nil
    end
  end

  def self.delete(id)
    OpenC3::Store.del("running-script:#{id}")
    running = OpenC3::Store.smembers("running-scripts")
    running.each do |item|
      parsed = JSON.parse(item, :allow_nan => true, :create_additions => true)
      if parsed["id"].to_s == id.to_s
        OpenC3::Store.srem("running-scripts", item)
        break
      end
    end
  end

  def self.spawn(scope, name, suite_runner = nil, disconnect = false, environment = nil)
    runner_path = File.join(RAILS_ROOT, 'scripts', 'run_script.rb')
    running_script_id = OpenC3::Store.incr('running-script-id')
    if RUBY_ENGINE != 'ruby'
      ruby_process_name = 'jruby'
    else
      ruby_process_name = 'ruby'
    end
    start_time = Time.now
    details = {
      id: running_script_id,
      scope: scope,
      name: name,
      start_time: start_time.to_s,
      disconnect: disconnect,
      environment: environment
    }
    OpenC3::Store.sadd('running-scripts', details.as_json(:allow_nan => true).to_json(:allow_nan => true))
    details[:hostname] = Socket.gethostname
    # details[:pid] = process.pid
    details[:state] = :spawning
    details[:line_no] = 1
    details[:update_time] = start_time.to_s
    details[:suite_runner] = suite_runner.as_json(:allow_nan => true).to_json(:allow_nan => true) if suite_runner
    OpenC3::Store.set("running-script:#{running_script_id}", details.as_json(:allow_nan => true).to_json(:allow_nan => true))

    process = ChildProcess.build(ruby_process_name, runner_path.to_s, running_script_id.to_s)
    process.io.inherit! # Helps with debugging
    process.cwd = File.join(RAILS_ROOT, 'scripts')

    # Set proper secrets for running script
    process.environment['SECRET_KEY_BASE'] = nil
    process.environment['OPENC3_REDIS_USERNAME'] = ENV['OPENC3_SR_REDIS_USERNAME']
    process.environment['OPENC3_REDIS_PASSWORD'] = ENV['OPENC3_SR_REDIS_PASSWORD']
    process.environment['OPENC3_MINIO_USERNAME'] = ENV['OPENC3_SR_MINIO_USERNAME']
    process.environment['OPENC3_MINIO_PASSWORD'] = ENV['OPENC3_SR_MINIO_PASSWORD']
    process.environment['OPENC3_SR_REDIS_USERNAME'] = nil
    process.environment['OPENC3_SR_REDIS_PASSWORD'] = nil
    process.environment['OPENC3_SR_MINIO_USERNAME'] = nil
    process.environment['OPENC3_SR_MINIO_PASSWORD'] = nil
    process.environment['OPENC3_API_USER'] = ENV['OPENC3_API_USER']
    process.environment['OPENC3_API_PASSWORD'] = ENV['OPENC3_API_PASSWORD'] || ENV['OPENC3_SERVICE_PASSWORD']
    process.environment['OPENC3_API_CLIENT'] = ENV['OPENC3_API_CLIENT']
    process.environment['OPENC3_API_SECRET'] = ENV['OPENC3_API_SECRET']
    process.environment['GEM_HOME'] = ENV['GEM_HOME']

    # Spawned process should not be controlled by same Bundler constraints as spawning process
    ENV.each do |key, value|
      if key =~ /^BUNDLE/
        process.environment[key] = nil
      end
    end
    process.environment['RUBYOPT'] = nil # Removes loading bundler setup

    process.start
    running_script_id
  end

  # Parameters are passed to RunningScript.new as strings because
  # RunningScript.spawn must pass strings to ChildProcess.build
  def initialize(id, scope, name, disconnect)
    @@instance = self
    @id = id
    @@id = id
    @scope = scope
    @name = name
    @filename = name
    @user_input = ''
    @prompt_id = nil
    @line_offset = 0
    @output_io = StringIO.new('', 'r+')
    @output_io_mutex = Mutex.new
    @allow_start = true
    @continue_after_error = true
    @debug_text = nil
    @debug_history = []
    @debug_code_completion = nil
    @top_level_instrumented_cache = nil
    @output_time = Time.now.sys
    @state = :init

    initialize_variables()
    redirect_io() # Redirect $stdout and $stderr
    mark_breakpoints(@filename)
    disconnect_script() if disconnect

    # Get details from redis

    details = OpenC3::Store.get("running-script:#{id}")
    if details
      @details = JSON.parse(details, :allow_nan => true, :create_additions => true)
    else
      # Create as much details as we know
      @details = { id: @id, name: @filename, scope: @scope, start_time: Time.now.to_s, update_time: Time.now.to_s }
    end

    # Update details in redis
    @details[:hostname] = Socket.gethostname
    @details[:state] = @state
    @details[:line_no] = 1
    @details[:update_time] = Time.now.to_s
    OpenC3::Store.set("running-script:#{id}", @details.as_json(:allow_nan => true).to_json(:allow_nan => true))

    # Retrieve file
    @body = ::Script.body(@scope, name)
    breakpoints = @@breakpoints[filename]&.filter { |_, present| present }&.map { |line_number, _| line_number - 1 } # -1 because frontend lines are 0-indexed
    breakpoints ||= []
    OpenC3::Store.publish(["script-api", "running-script-channel:#{@id}"].compact.join(":"),
                          JSON.generate({ type: :file, filename: @filename, scope: @scope, text: @body, breakpoints: breakpoints }))
    if name.include?("suite")
      # Process the suite file in this context so we can load it
      # TODO: Do we need to worry about success or failure of the suite processing?
      ::Script.process_suite(name, @body, new_process: false, scope: @scope)
      # Call load_utility to parse the suite and allow for individual methods to be executed
      load_utility(name)
    end
  end

  def parse_options(options)
    settings = {}
    if options.include?('manual')
      settings['Manual'] = true
      $manual = true
    else
      settings['Manual'] = false
      $manual = false
    end
    if options.include?('pauseOnError')
      settings['Pause on Error'] = true
      @@pause_on_error = true
    else
      settings['Pause on Error'] = false
      @@pause_on_error = false
    end
    if options.include?('continueAfterError')
      settings['Continue After Error'] = true
      @continue_after_error = true
    else
      settings['Continue After Error'] = false
      @continue_after_error = false
    end
    if options.include?('abortAfterError')
      settings['Abort After Error'] = true
      OpenC3::Test.abort_on_exception = true
    else
      settings['Abort After Error'] = false
      OpenC3::Test.abort_on_exception = false
    end
    if options.include?('loop')
      settings['Loop'] = true
    else
      settings['Loop'] = false
    end
    if options.include?('breakLoopOnError')
      settings['Break Loop On Error'] = true
    else
      settings['Break Loop On Error'] = false
    end
    OpenC3::SuiteRunner.settings = settings
  end

  # Let the script continue pausing if in step mode
  def continue
    @go = true
    @pause = true if @step
  end

  # Sets step mode and lets the script continue but with pause set
  def step
    @step = true
    @go = true
    @pause = true
  end

  # Clears step mode and lets the script continue
  def go
    @step = false
    @go = true
    @pause = false
  end

  def go?
    temp = @go
    @go = false
    temp
  end

  def pause
    @pause = true
    @go    = false
  end

  def pause?
    @pause
  end

  def stop
    if @@run_thread
      @stop = true
      OpenC3.kill_thread(self, @@run_thread)
      @@run_thread = nil
    end
  end

  def stop?
    @stop
  end

  def clear_prompt
    # Allow things to continue once the prompt is cleared
    OpenC3::Store.publish(["script-api", "running-script-channel:#{@id}"].compact.join(":"), JSON.generate({ type: :script, prompt_complete: @prompt_id }))
    @prompt_id = nil
  end

  def as_json(*args)
    { id: @id, state: @state, filename: @current_filename, line_no: @current_line_no }
  end

  # Private methods

  def graceful_kill
    @stop = true
  end

  def initialize_variables
    @@error = nil
    @go = false
    @pause = false
    @step = false
    @stop = false
    @retry_needed = false
    @use_instrumentation = true
    @call_stack = []
    @pre_line_time = Time.now.sys
    @current_file = @filename
    @exceptions = nil
    @script_binding = nil
    @inline_eval = nil
    @current_filename = nil
    @current_line_number = 0
    @stdout_max_lines = 1000

    @call_stack.push(@current_file.dup)
  end

  def unique_filename
    if @filename and !@filename.empty?
      return @filename
    else
      return "Untitled" + @id.to_s
    end
  end

  def stop_message_log
    metadata = {
      "scriptname" => unique_filename()
    }
    @@message_log.stop(true, s3_object_metadata: metadata) if @@message_log
    @@message_log = nil
  end

  def filename=(filename)
    # Stop the message log so a new one will be created with the new filename
    stop_message_log()
    @filename = filename

    # Deal with breakpoints created under the previous filename.
    bkpt_filename = unique_filename()
    if @@breakpoints[bkpt_filename].nil?
      @@breakpoints[bkpt_filename] = @@breakpoints[@filename]
    end
    if bkpt_filename != @filename
      @@breakpoints.delete(@filename)
      @filename = bkpt_filename
    end
    mark_breakpoints(@filename)
  end

  attr_writer :allow_start

  def self.instance
    @@instance
  end

  def self.instance=(value)
    @@instance = value
  end

  def self.line_delay
    @@line_delay
  end

  def self.line_delay=(value)
    @@line_delay = value
  end

  def self.breakpoints
    @@breakpoints
  end

  def self.instrumented_cache
    @@instrumented_cache
  end

  def self.instrumented_cache=(value)
    @@instrumented_cache = value
  end

  def self.file_cache
    @@file_cache
  end

  def self.file_cache=(value)
    @@file_cache = value
  end

  def self.pause_on_error
    @@pause_on_error
  end

  def self.pause_on_error=(value)
    @@pause_on_error = value
  end

  def self.monitor_limits
    @@monitor_limits
  end

  def self.monitor_limits=(value)
    @@monitor_limits = value
  end

  def self.pause_on_red
    @@pause_on_red
  end

  def self.pause_on_red=(value)
    @@pause_on_red = value
  end

  def self.show_backtrace
    @@show_backtrace
  end

  def self.show_backtrace=(value)
    @@show_backtrace = value
    if @@show_backtrace and @@error
      puts Time.now.sys.formatted + " (SCRIPTRUNNER): " + "Most recent exception:\n" + @@error.formatted
    end
  end

  def text
    @body
  end

  def set_text(text, filename = '')
    unless running?()
      # @script.setPlainText(text)
      # @script.stop_highlight
      @filename = filename
      # @script.filename = unique_filename()
      mark_breakpoints(@filename)
      @body = text
    end
  end

  def self.running?
    if @@run_thread then true else false end
  end

  def running?
    if @@instance == self and RunningScript.running?() then true else false end
  end

  def retry_needed
    @retry_needed = true
  end

  def disable_retry
    # @realtime_button_bar.start_button.setText('Skip')
    # @realtime_button_bar.pause_button.setDisabled(true)
  end

  def enable_retry
    # @realtime_button_bar.start_button.setText('Go')
    # @realtime_button_bar.pause_button.setDisabled(false)
  end

  def run
    unless self.class.running?()
      run_text(@body)
    end
  end

  def run_and_close_on_complete(text_binding = nil)
    run_text(@body, 0, text_binding, true)
  end

  def self.instrument_script(text, filename, mark_private = false)
    if filename and !filename.empty?
      @@file_cache[filename] = text.clone
    end

    ruby_lex_utils = RubyLexUtils.new
    instrumented_text = ''

    @cancel_instrumentation = false
    comments_removed_text = ruby_lex_utils.remove_comments(text)
    num_lines = comments_removed_text.num_lines.to_f
    num_lines = 1 if num_lines < 1
    instrumented_text =
      instrument_script_implementation(ruby_lex_utils,
                                        comments_removed_text,
                                        num_lines,
                                        filename,
                                        mark_private)

    raise OpenC3::StopScript if @cancel_instrumentation
    instrumented_text
  end

  def self.instrument_script_implementation(ruby_lex_utils,
                                            comments_removed_text,
                                            num_lines,
                                            filename,
                                            mark_private = false)
    if mark_private
      instrumented_text = 'private; '
    else
      instrumented_text = ''
    end

    ruby_lex_utils.each_lexed_segment(comments_removed_text) do |segment, instrumentable, inside_begin, line_no|
      return nil if @cancel_instrumentation
      instrumented_line = ''
      if instrumentable
        # Add a newline if it's empty to ensure the instrumented code has
        # the same number of lines as the original script. Note that the
        # segment could have originally had comments but they were stripped in
        # ruby_lex_utils.remove_comments
        if segment.strip.empty?
          instrumented_text << "\n"
          next
        end

        # Create a variable to hold the segment's return value
        instrumented_line << "__return_val = nil; "

        # If not inside a begin block then create one to catch exceptions
        unless inside_begin
          instrumented_line << 'begin; '
        end

        # Add preline instrumentation
        instrumented_line << "RunningScript.instance.script_binding = binding(); "\
          "RunningScript.instance.pre_line_instrumentation('#{filename}', #{line_no}); "

        # Add the actual line
        instrumented_line << "__return_val = begin; "
        instrumented_line << segment
        instrumented_line.chomp!

        # Add postline instrumentation
        instrumented_line << " end; RunningScript.instance.post_line_instrumentation('#{filename}', #{line_no}); "

        # Complete begin block to catch exceptions
        unless inside_begin
          instrumented_line << "rescue Exception => eval_error; "\
          "retry if RunningScript.instance.exception_instrumentation(eval_error, '#{filename}', #{line_no}); end; "
        end

        instrumented_line << " __return_val\n"
      else
        unless segment =~ /^\s*end\s*$/ or segment =~ /^\s*when .*$/
          num_left_brackets = segment.count('{')
          num_right_brackets = segment.count('}')
          num_left_square_brackets = segment.count('[')
          num_right_square_brackets = segment.count(']')

          if (num_right_brackets > num_left_brackets) ||
            (num_right_square_brackets > num_left_square_brackets)
            instrumented_line = segment
          else
            instrumented_line = "RunningScript.instance.pre_line_instrumentation('#{filename}', #{line_no}); " + segment
          end
        else
          instrumented_line = segment
        end
      end

      instrumented_text << instrumented_line

      # progress_dialog.set_overall_progress(line_no / num_lines) if progress_dialog and line_no
    end
    instrumented_text
  end

  def pre_line_instrumentation(filename, line_number)
    @current_filename = filename
    @current_line_number = line_number
    if @use_instrumentation
      # Clear go
      @go = false

      # Handle stopping mid-script if necessary
      raise OpenC3::StopScript if @stop

      handle_potential_tab_change(filename)

      # Adjust line number for offset in main script
      line_number = line_number + @line_offset # if @active_script.object_id == @script.object_id
      detail_string = nil
      if filename
        detail_string = File.basename(filename) << ':' << line_number.to_s
        OpenC3::Logger.detail_string = detail_string
      end

      OpenC3::Store.publish(["script-api", "running-script-channel:#{@id}"].compact.join(":"), JSON.generate({ type: :line, filename: @current_filename, line_no: @current_line_number, state: :running }))
      handle_pause(filename, line_number)
      handle_line_delay()
    end
  end

  def post_line_instrumentation(filename, line_number)
    if @use_instrumentation
      line_number = line_number + @line_offset # if @active_script.object_id == @script.object_id
      handle_output_io(filename, line_number)
    end
  end

  def exception_instrumentation(error, filename, line_number)
    if error.class <= OpenC3::StopScript || error.class <= OpenC3::SkipScript || !@use_instrumentation
      raise error
    elsif !error.eql?(@@error)
      line_number = line_number + @line_offset # if @active_script.object_id == @script.object_id
      handle_exception(error, false, filename, line_number)
    end
  end

  def perform_wait(prompt)
    mark_waiting()
    wait_for_go_or_stop(prompt: prompt)
  end

  def perform_pause
    mark_paused()
    wait_for_go_or_stop()
  end

  def perform_breakpoint(filename, line_number)
    mark_breakpoint()
    scriptrunner_puts "Hit Breakpoint at #{filename}:#{line_number}"
    handle_output_io(filename, line_number)
    wait_for_go_or_stop()
  end

  def debug(debug_text)
    handle_output_io()
    if not running?
      # Capture STDOUT and STDERR
      $stdout.add_stream(@output_io)
      $stderr.add_stream(@output_io)
    end

    if @script_binding
      # Check for accessing an instance variable or local
      if debug_text =~ /^@\S+$/ || @script_binding.local_variables.include?(debug_text.to_sym)
        debug_text = "puts #{debug_text}" # Automatically add puts to print it
      end
      eval(debug_text, @script_binding, 'debug', 1)
    else
      Object.class_eval(debug_text, 'debug', 1)
    end
    handle_output_io()
  rescue Exception => error
    if error.class == DRb::DRbConnError
      OpenC3::Logger.error("Error Connecting to Command and Telemetry Server")
    else
      OpenC3::Logger.error(error.class.to_s.split('::')[-1] + ' : ' + error.message)
    end
    handle_output_io()
  ensure
    if not running?
      # Capture STDOUT and STDERR
      $stdout.remove_stream(@output_io)
      $stderr.remove_stream(@output_io)
    end
  end

  # TODO: Do we still want a 'Locals' button ... not sure how useful this is
  #     @locals_button = Qt::PushButton.new('Locals')
  #     @locals_button.connect(SIGNAL('clicked(bool)')) do
  #       next unless @script_binding
  #       @locals_button.setEnabled(false)
  #       vars = @script_binding.local_variables.map(&:to_s)
  #       puts "Locals: #{vars.reject {|x| INSTANCE_VARS.include?(x)}.sort.join(', ')}"
  #       while @output_io.string[-1..-1] == "\n"
  #         Qt::CoreApplication.processEvents()
  #       end
  #       @locals_button.setEnabled(true)
  #     end
  #     @debug_frame.addWidget(@locals_button)

  def self.set_breakpoint(filename, line_number)
    @@breakpoints[filename] ||= {}
    @@breakpoints[filename][line_number] = true
  end

  def self.clear_breakpoint(filename, line_number)
    @@breakpoints[filename] ||= {}
    @@breakpoints[filename].delete(line_number) if @@breakpoints[filename][line_number]
  end

  def self.clear_breakpoints(filename = nil)
    if filename == nil or filename.empty?
      @@breakpoints = {}
    else
      @@breakpoints.delete(filename)
    end
  end

  def clear_breakpoints
    ScriptRunnerFrame.clear_breakpoints(unique_filename())
  end

  def current_backtrace
    trace = []
    if @@run_thread
      temp_trace = @@run_thread.backtrace
      temp_trace.each do |line|
        next if line.include?(OpenC3::PATH)    # Ignore OpenC3 internals
        next if line.include?('lib/ruby/gems') # Ignore system gems
        next if line.include?('app/models/running_script') # Ignore this file
        trace << line
      end
    end
    trace
  end

  def scriptrunner_puts(string, color = 'BLACK')
    line_to_write = Time.now.sys.formatted + " (SCRIPTRUNNER): " + string
    OpenC3::Store.publish(["script-api", "running-script-channel:#{@id}"].compact.join(":"), JSON.generate({ type: :output, line: line_to_write, color: color }))
  end

  def handle_output_io(filename = @current_filename, line_number = @current_line_number)
    @output_time = Time.now.sys
    if @output_io.string[-1..-1] == "\n"
      time_formatted = Time.now.sys.formatted
      color = 'BLACK'
      lines_to_write = ''
      out_line_number = line_number.to_s
      out_filename = File.basename(filename) if filename

      # Build each line to write
      string = @output_io.string.clone
      @output_io.string = @output_io.string[string.length..-1]
      line_count = 0
      string.each_line do |out_line|
        begin
          json = JSON.parse(out_line, :allow_nan => true, :create_additions => true)
          time_formatted = Time.parse(json["@timestamp"]).sys.formatted if json["@timestamp"]
          out_line = json["log"] if json["log"]
        rescue
          # Regular output
        end

        if out_line.length >= 25 and out_line[0..1] == '20' and out_line[10] == ' ' and out_line[23..24] == ' ('
          line_to_write = out_line
        else
          if filename
            line_to_write = time_formatted + " (#{out_filename}:#{out_line_number}): " + out_line
          else
            line_to_write = time_formatted + " (SCRIPTRUNNER): " + out_line
            color = 'BLUE'
          end
        end

        OpenC3::Store.publish(["script-api", "running-script-channel:#{@id}"].compact.join(":"), JSON.generate({ type: :output, line: line_to_write.as_json(:allow_nan => true), color: color }))
        lines_to_write << line_to_write

        line_count += 1
        if line_count > @stdout_max_lines
          out_line = "ERROR: Too much written to stdout.  Truncating output to #{@stdout_max_lines} lines.\n"
          if filename
            line_to_write = time_formatted + " (#{out_filename}:#{out_line_number}): " + out_line
          else
            line_to_write = time_formatted + " (SCRIPTRUNNER): " + out_line
          end

          OpenC3::Store.publish(["script-api", "running-script-channel:#{@id}"].compact.join(":"), JSON.generate({ type: :output, line: line_to_write.as_json(:allow_nan => true), color: 'RED' }))
          lines_to_write << line_to_write
          break
        end
      end # string.each_line

      # Add to the message log
      message_log.write(lines_to_write)
    end
  end

  def graceful_kill
    # Just to avoid warning
  end

  def wait_for_go_or_stop(error = nil, prompt: nil)
    count = -1
    @go = false
    @prompt_id = prompt['id'] if prompt
    until (@go or @stop)
      sleep(0.01)
      count += 1
      if count % 100 == 0 # Approximately Every Second
        OpenC3::Store.publish(["script-api", "running-script-channel:#{@id}"].compact.join(":"), JSON.generate({ type: :line, filename: @current_filename, line_no: @current_line_number, state: @state }))
        OpenC3::Store.publish(["script-api", "running-script-channel:#{@id}"].compact.join(":"), JSON.generate({ type: :script, method: prompt['method'], prompt_id: prompt['id'], args: prompt['args'], kwargs: prompt['kwargs'] })) if prompt
      end
    end
    clear_prompt() if prompt
    RunningScript.instance.prompt_id = nil
    @go = false
    mark_running()
    raise OpenC3::StopScript if @stop
    raise error if error and !@continue_after_error
  end

  def wait_for_go_or_stop_or_retry(error = nil)
    count = 0
    @go = false
    until (@go or @stop or @retry_needed)
      sleep(0.01)
      count += 1
      if (count % 100) == 0 # Approximately Every Second
        OpenC3::Store.publish(["script-api", "running-script-channel:#{@id}"].compact.join(":"), JSON.generate({ type: :line, filename: @current_filename, line_no: @current_line_number, state: @state }))
      end
    end
    @go = false
    mark_running()
    raise OpenC3::StopScript if @stop
    raise error if error and !@continue_after_error
  end

  def mark_running
    @state = :running
    OpenC3::Store.publish(["script-api", "running-script-channel:#{@id}"].compact.join(":"), JSON.generate({ type: :line, filename: @current_filename, line_no: @current_line_number, state: @state }))
  end

  def mark_paused
    @state = :paused
    OpenC3::Store.publish(["script-api", "running-script-channel:#{@id}"].compact.join(":"), JSON.generate({ type: :line, filename: @current_filename, line_no: @current_line_number, state: @state }))
  end

  def mark_waiting
    @state = :waiting
    OpenC3::Store.publish(["script-api", "running-script-channel:#{@id}"].compact.join(":"), JSON.generate({ type: :line, filename: @current_filename, line_no: @current_line_number, state: @state }))
  end

  def mark_error
    @state = :error
    OpenC3::Store.publish(["script-api", "running-script-channel:#{@id}"].compact.join(":"), JSON.generate({ type: :line, filename: @current_filename, line_no: @current_line_number, state: @state }))
  end

  def mark_fatal
    @state = :fatal
    OpenC3::Store.publish(["script-api", "running-script-channel:#{@id}"].compact.join(":"), JSON.generate({ type: :line, filename: @current_filename, line_no: @current_line_number, state: @state }))
  end

  def mark_stopped
    @state = :stopped
    OpenC3::Store.publish(["script-api", "running-script-channel:#{@id}"].compact.join(":"), JSON.generate({ type: :line, filename: @current_filename, line_no: @current_line_number, state: @state }))
    if OpenC3::SuiteRunner.suite_results
      OpenC3::SuiteRunner.suite_results.complete
      OpenC3::Store.publish(["script-api", "running-script-channel:#{@id}"].compact.join(":"), JSON.generate({ type: :report, report: OpenC3::SuiteRunner.suite_results.report }))
      log_dir = File.join(RAILS_ROOT, 'log')
      filename = File.join(log_dir, File.build_timestamped_filename(['sr', 'report']))
      File.open(filename, 'wb') do |file|
        file.write(OpenC3::SuiteRunner.suite_results.report)
      end
      s3_key = File.join("#{@scope}/tool_logs/sr/", File.basename(filename)[0..9].gsub("_", ""), File.basename(filename))
      thread = OpenC3::S3Utilities.move_log_file_to_s3(filename, s3_key)
      # Wait for the file to get moved to S3 because after this the process will likely die
      thread.join
    end
    OpenC3::Store.publish(["script-api", "cmd-running-script-channel:#{@id}"].compact.join(":"), JSON.generate("shutdown"))
  end

  def mark_breakpoint
    @state = :breakpoint
    OpenC3::Store.publish(["script-api", "running-script-channel:#{@id}"].compact.join(":"), JSON.generate({ type: :line, filename: @current_filename, line_no: @current_line_number, state: @state }))
  end

  def run_text(text,
                line_offset = 0,
                text_binding = nil,
                close_on_complete = false)
    initialize_variables()
    @line_offset = line_offset
    saved_instance = @@instance
    saved_run_thread = @@run_thread
    @@instance   = self
    @@run_thread = Thread.new do
      uncaught_exception = false
      begin
        # Capture STDOUT and STDERR
        $stdout.add_stream(@output_io)
        $stderr.add_stream(@output_io)

        unless close_on_complete
          output = "Starting script: #{File.basename(@filename)}"
          output += " in DISCONNECT mode" if $disconnect
          scriptrunner_puts(output)
        end
        handle_output_io()

        # Start Limits Monitoring
        @@limits_monitor_thread = Thread.new { limits_monitor_thread() } if @@monitor_limits and !@@limits_monitor_thread

        # Start Output Thread
        @@output_thread = Thread.new { output_thread() } unless @@output_thread

        # Check top level cache
        if @top_level_instrumented_cache &&
          (@top_level_instrumented_cache[1] == line_offset) &&
          (@top_level_instrumented_cache[2] == @filename) &&
          (@top_level_instrumented_cache[0] == text)
          # Use the instrumented cache
          instrumented_script = @top_level_instrumented_cache[3]
        else
          # Instrument the script
          if text_binding
            instrumented_script = self.class.instrument_script(text, @filename, false)
          else
            instrumented_script = self.class.instrument_script(text, @filename, true)
          end
          @top_level_instrumented_cache = [text, line_offset, @filename, instrumented_script]
        end

        # Execute the script with warnings disabled
        OpenC3.disable_warnings do
          @pre_line_time = Time.now.sys
          if text_binding
            eval(instrumented_script, text_binding, @filename, 1)
          else
            Object.class_eval(instrumented_script, @filename, 1)
          end
        end

        handle_output_io()
        scriptrunner_puts "Script completed: #{File.basename(@filename)}" unless close_on_complete

      rescue Exception => error
        if error.class <= OpenC3::StopScript or error.class <= OpenC3::SkipScript
          handle_output_io()
          scriptrunner_puts "Script stopped: #{File.basename(@filename)}"
        else
          uncaught_exception = true
          filename, line_number = error.source
          handle_exception(error, true, filename, line_number)
          handle_output_io()
          scriptrunner_puts "Exception in Control Statement - Script stopped: #{File.basename(@filename)}"
          mark_fatal()
        end
      ensure
        # Stop Capturing STDOUT and STDERR
        # Check for remove_stream because if the tool is quitting the
        # OpenC3::restore_io may have been called which sets $stdout and
        # $stderr to the IO constant
        $stdout.remove_stream(@output_io) if $stdout.respond_to? :remove_stream
        $stderr.remove_stream(@output_io) if $stderr.respond_to? :remove_stream

        # Clear run thread and instance to indicate we are no longer running
        @@instance = saved_instance
        @@run_thread = saved_run_thread
        @active_script = @script
        @script_binding = nil
        # Set the current_filename to the original file and the current_line_number to 0
        # so the mark_stopped method will signal the frontend to reset to the original
        @current_filename = @filename
        @current_line_number = 0
        if @@limits_monitor_thread and not @@instance
          @@cancel_limits = true
          @@limits_sleeper.cancel
          OpenC3.kill_thread(self, @@limits_monitor_thread)
          @@limits_monitor_thread = nil
        end
        if @@output_thread and not @@instance
          @@cancel_output = true
          @@output_sleeper.cancel
          OpenC3.kill_thread(self, @@output_thread)
          @@output_thread = nil
        end
        mark_stopped()
        @current_filename = nil
      end
    end
  end

  def handle_potential_tab_change(filename)
    # Make sure the correct file is shown in script runner
    if @current_file != filename
      # Qt.execute_in_main_thread(true) do
      if @call_stack.include?(filename)
        index = @call_stack.index(filename)
        # select_tab_and_destroy_tabs_after_index(index)
      else # new file
        # Create new tab
        # new_script = create_ruby_editor()
        # new_script.filename = filename
        # @tab_book.addTab(new_script, '  ' + File.basename(filename) + '  ')

        @call_stack.push(filename.dup)

        # Switch to new tab
        # @tab_book.setCurrentIndex(@tab_book.count - 1)
        # @active_script = new_script
        load_file_into_script(filename)
        # new_script.setReadOnly(true)
      end

      @current_file = filename
      # end
    end
  end

  def show_active_tab
    # @tab_book.setCurrentIndex(@call_stack.length - 1) if @tab_book_shown
  end

  def handle_pause(filename, line_number)
    breakpoint = false
    breakpoint = true if @@breakpoints[filename] and @@breakpoints[filename][line_number]

    filename = File.basename(filename)
    if @pause
      @pause = false unless @step
      if breakpoint
        perform_breakpoint(filename, line_number)
      else
        perform_pause()
      end
    else
      perform_breakpoint(filename, line_number) if breakpoint
    end
  end

  def handle_line_delay
    if @@line_delay > 0.0
      sleep_time = @@line_delay - (Time.now.sys - @pre_line_time)
      sleep(sleep_time) if sleep_time > 0.0
    end
    @pre_line_time = Time.now.sys
  end

  def continue_without_pausing_on_errors?
    if !@@pause_on_error
      # if Qt::MessageBox.warning(self, "Warning", "If an error occurs, the script will not pause and will run to completion. Continue?", Qt::MessageBox::Yes | Qt::MessageBox::No, Qt::MessageBox::Yes) == Qt::MessageBox::No
      #  return false
      # end
    end
    true
  end

  def handle_exception(error, fatal, filename = nil, line_number = 0)
    @exceptions ||= []
    @exceptions << error
    @@error = error

    if error.class == DRb::DRbConnError
      OpenC3::Logger.error("Error Connecting to Command and Telemetry Server")
    elsif error.class == OpenC3::CheckError
      OpenC3::Logger.error(error.message)
    else
      OpenC3::Logger.error(error.class.to_s.split('::')[-1] + ' : ' + error.message)
      relevent_lines = error.backtrace.select { |line| !line.include?("/src/app") && !line.include?("/openc3/lib") && !line.include?("/usr/lib/ruby") }
      OpenC3::Logger.error(relevent_lines.join("\n\n")) unless relevent_lines.empty?
    end
    handle_output_io(filename, line_number)

    raise error if !@@pause_on_error and !@continue_after_error and !fatal

    if !fatal and @@pause_on_error
      mark_error()
      wait_for_go_or_stop_or_retry(error)
    end

    if @retry_needed
      @retry_needed = false
      true
    else
      false
    end
  end

  def load_file_into_script(filename)
    mark_breakpoints(filename)
    breakpoints = @@breakpoints[filename]&.filter { |_, present| present }&.map { |line_number, _| line_number - 1 } # -1 because frontend lines are 0-indexed
    breakpoints ||= []
    cached = @@file_cache[filename]
    if cached
      # @active_script.setPlainText(cached.gsub("\r", ''))
      @body = cached
      OpenC3::Store.publish(["script-api", "running-script-channel:#{@id}"].compact.join(":"), JSON.generate({ type: :file, filename: filename, text: @body, breakpoints: breakpoints }))
    else
      text = ::Script.body(@scope, filename)
      @@file_cache[filename] = text
      @body = text
      OpenC3::Store.publish(["script-api", "running-script-channel:#{@id}"].compact.join(":"), JSON.generate({ type: :file, filename: filename, text: @body, breakpoints: breakpoints }))
    end

    # @active_script.stop_highlight
  end

  def mark_breakpoints(filename)
    breakpoints = @@breakpoints[filename]
    if breakpoints
      breakpoints.each do |line_number, present|
        RunningScript.set_breakpoint(filename, line_number) if present
      end
    else
      ::Script.get_breakpoints(@scope, filename).each do |line_number|
        RunningScript.set_breakpoint(filename, line_number + 1)
      end
    end
  end

  def redirect_io
    # Redirect Standard Output and Standard Error
    $stdout = OpenC3::Stdout.instance
    $stderr = OpenC3::Stderr.instance

    # Disable outputting to default io file descriptors
    # $stdout.remove_default_io
    # $stderr.remove_default_io

    OpenC3::Logger.stdout = true
    OpenC3::Logger.level = OpenC3::Logger::INFO
    OpenC3::Logger::INFO_SEVERITY_STRING.replace('')
    OpenC3::Logger::WARN_SEVERITY_STRING.replace('<Y> WARN:')
    OpenC3::Logger::ERROR_SEVERITY_STRING.replace('<R> ERROR:')
  end

  # def isolate_string(keyword, line)
  #   found_string = nil

  #   # Find keyword
  #   keyword_index = line.index(keyword)

  #   # Remove keyword from line
  #   line = line[(keyword_index + keyword.length)..-1]

  #   # Find start parens
  #   start_parens = line.index('(')
  #   if start_parens
  #     end_parens   = line[start_parens..-1].index(')')
  #     found_string = line[(start_parens + 1)..(end_parens + start_parens - 1)].remove_quotes if end_parens
  #     if keyword == 'wait' or keyword == 'wait_check'
  #       quote_index = found_string.rindex('"')
  #       quote_index = found_string.rindex("'") unless quote_index
  #       if quote_index
  #         found_string = found_string[0..quote_index].remove_quotes
  #       else
  #         found_string = nil
  #       end
  #     end
  #   end
  #   found_string
  # end

  # def mnemonic_check_cmd_line(keyword, line_number, line)
  #   result = nil

  #   # Isolate the string
  #   string = isolate_string(keyword, line)
  #   if string
  #     begin
  #       target_name, cmd_name, cmd_params = extract_fields_from_cmd_text(string)
  #       result = "At line #{line_number}: Unknown command: #{target_name} #{cmd_name}"
  #       packet = System.commands.packet(target_name, cmd_name)
  #       Kernel.raise "Command not found" unless packet
  #       cmd_params.each do |param_name, param_value|
  #         result = "At line #{line_number}: Unknown command parameter: #{target_name} #{cmd_name} #{param_name}"
  #         packet.get_item(param_name)
  #       end
  #       result = nil
  #     rescue
  #       if result
  #         if string.index('=>')
  #           # Assume alternative syntax
  #           result = nil
  #         end
  #       else
  #         result = "At line #{line_number}: Potentially malformed command: #{line}"
  #       end
  #     end
  #   end

  #   result
  # end

  # def _mnemonic_check_tlm_line(keyword, line_number, line)
  #   result = nil

  #   # Isolate the string
  #   string = isolate_string(keyword, line)
  #   if string
  #     begin
  #       target_name, packet_name, item_name = yield string
  #       result = "At line #{line_number}: Unknown telemetry item: #{target_name} #{packet_name} #{item_name}"
  #       System.telemetry.packet_and_item(target_name, packet_name, item_name)
  #       result = nil
  #     rescue
  #       if result
  #         if string.index(',')
  #           # Assume alternative syntax
  #           result = nil
  #         end
  #       else
  #         result = "At line #{line_number}: Potentially malformed telemetry: #{line}"
  #       end
  #     end
  #   end

  #   result
  # end

  # def mnemonic_check_tlm_line(keyword, line_number, line)
  #   _mnemonic_check_tlm_line(keyword, line_number, line) do |string|
  #     extract_fields_from_tlm_text(string)
  #   end
  # end

  # def mnemonic_check_set_tlm_line(keyword, line_number, line)
  #   _mnemonic_check_tlm_line(keyword, line_number, line) do |string|
  #     extract_fields_from_set_tlm_text(string)
  #   end
  # end

  # def mnemonic_check_check_line(keyword, line_number, line)
  #   _mnemonic_check_tlm_line(keyword, line_number, line) do |string|
  #     extract_fields_from_check_text(string)
  #   end
  # end

  def output_thread
    @@cancel_output = false
    @@output_sleeper = OpenC3::Sleeper.new
    begin
      loop do
        break if @@cancel_output
        handle_output_io() if (Time.now.sys - @output_time) > 5.0
        break if @@cancel_output
        break if @@output_sleeper.sleep(1.0)
      end # loop
    rescue => error
      # Qt.execute_in_main_thread(true) do
      #  ExceptionDialog.new(self, error, "Output Thread")
      # end
    end
  end

  def limits_monitor_thread
    @@cancel_limits = false
    @@limits_sleeper = OpenC3::Sleeper.new
    queue_id = nil
    begin
      loop do
        break if @@cancel_limits
        begin
          # Subscribe to limits notifications
          queue_id = subscribe_limits_events(100000) unless queue_id

          # Get the next limits event
          break if @@cancel_limits
          begin
            type, data = get_limits_event(queue_id, true)
          rescue ThreadError
            break if @@cancel_limits
            break if @@limits_sleeper.sleep(0.5)
            next
          end

          break if @@cancel_limits

          # Display limits state changes
          if type == :LIMITS_CHANGE
            target_name = data[0]
            packet_name = data[1]
            item_name = data[2]
            old_limits_state = data[3]
            new_limits_state = data[4]

            if old_limits_state == nil # Changing from nil
              if (new_limits_state != :GREEN) &&
                (new_limits_state != :GREEN_LOW) &&
                (new_limits_state != :GREEN_HIGH) &&
                (new_limits_state != :BLUE)
                msg = "#{target_name} #{packet_name} #{item_name} is #{new_limits_state}"
                case new_limits_state
                when :YELLOW, :YELLOW_LOW, :YELLOW_HIGH
                  scriptrunner_puts(msg, 'YELLOW')
                when :RED, :RED_LOW, :RED_HIGH
                  scriptrunner_puts(msg, 'RED')
                else
                  # Print nothing
                end
                handle_output_io()
              end
            else # changing from a color
              msg = "#{target_name} #{packet_name} #{item_name} is #{new_limits_state}"
              case new_limits_state
              when :BLUE
                scriptrunner_puts(msg)
              when :GREEN, :GREEN_LOW, :GREEN_HIGH
                scriptrunner_puts(msg, 'GREEN')
              when :YELLOW, :YELLOW_LOW, :YELLOW_HIGH
                scriptrunner_puts(msg, 'YELLOW')
              when :RED, :RED_LOW, :RED_HIGH
                scriptrunner_puts(msg, 'RED')
              else
                # Print nothing
              end
              break if @@cancel_limits
              handle_output_io()
              break if @@cancel_limits
            end

            if @@pause_on_red && (new_limits_state == :RED ||
                                  new_limits_state == :RED_LOW ||
                                  new_limits_state == :RED_HIGH)
              break if @@cancel_limits
              pause()
              break if @@cancel_limits
            end
          end

        rescue DRb::DRbConnError
          queue_id = nil
          break if @@cancel_limits
          break if @@limits_sleeper.sleep(1)
        end
      end # loop
    rescue => error
      # Qt.execute_in_main_thread(true) do
      #  ExceptionDialog.new(self, error, "Limits Monitor Thread")
      # end
    end
  ensure
    begin
      unsubscribe_limits_events(queue_id) if queue_id
    rescue
      # Oh Well
    end
  end

end
