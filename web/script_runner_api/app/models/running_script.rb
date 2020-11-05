require 'json'
require 'thread'
require 'cosmos'
require 'cosmos/script'
require 'cosmos/io/stdout'
require 'cosmos/io/stderr'
require 'redis'
require 'childprocess'

module Cosmos
  module Script
    private

    # Define all the user input methods used in scripting which we need to broadcast to the frontend
    SCRIPT_METHODS = %i[ask_string prompt_dialog_box prompt_for_hazardous prompt_to_continue prompt_combo_box prompt_message_box prompt_vertical_message_box]
    SCRIPT_METHODS.each do |method|
      define_method(method) do |*args|
        RunningScript.instance.scriptrunner_puts("#{method}(#{args.join(', ')})")
        ActionCable.server.broadcast("running-script-channel:#{RunningScript.instance.id}", { type: :script, method: method, args: args })
        RunningScript.instance.perform_pause
        return RunningScript.instance.user_input
      end
    end

    Cosmos.disable_warnings do
      def prompt_for_script_abort
        RunningScript.instance.perform_pause
        return false # Not aborted - Retry
      end

      def start(procedure_name, bucket = nil)
        bucket ||= ::Script::DEFAULT_BUCKET_NAME
        path = procedure_name

        # Check RAM based instrumented cache
        instrumented_cache, text = RunningScript.instrumented_cache[path]
        instrumented_script = nil
        if instrumented_cache
          # Use cached instrumentation
          instrumented_script = instrumented_cache
          cached = true
          ActionCable.server.broadcast("running-script-channel:#{RunningScript.instance.id}", { type: :file, filename: procedure_name, bucket: bucket, text: text })
        else
          # Retrieve file
          text = ::Script.body(procedure_name, bucket)
          ActionCable.server.broadcast("running-script-channel:#{RunningScript.instance.id}", { type: :file, filename: procedure_name, bucket: bucket, text: text })

          # Cache instrumentation into RAM
          instrumented_script = RunningScript.instrument_script(text, path, bucket, true)
          RunningScript.instrumented_cache[path] = [instrumented_script, text]
          cached = false
        end

        Object.class_eval(instrumented_script, path, 1)

        # Return whether we had to load and instrument this file, i.e. it was not cached
        !cached
      end

      # Require an additional ruby file
      def load_utility(procedure_name, bucket = nil)
        bucket ||= ::Script::DEFAULT_BUCKET_NAME
        not_cached = false
        if defined? RunningScript and RunningScript.instance
          saved = RunningScript.instance.use_instrumentation
          begin
            RunningScript.instance.use_instrumentation = false
            not_cached = start(procedure_name, bucket)
          ensure
            RunningScript.instance.use_instrumentation = saved
          end
        else # Just call start
          not_cached = start(procedure_name, bucket)
        end
        # Return whether we had to load and instrument this file, i.e. it was not cached
        # This is designed to match the behavior of Ruby's require and load keywords
        not_cached
      end
      alias require_utility load_utility

      # sleep in a script - returns true if canceled mid sleep
      def cosmos_script_sleep(sleep_time = nil)
        ActionCable.server.broadcast("running-script-channel:#{RunningScript.instance.id}",
          { type: :line, filename: RunningScript.instance.current_filename, line_no: RunningScript.instance.current_line_number, state: :waiting })

        sleep_time = 30000000 unless sleep_time # Handle infinite wait
        if sleep_time > 0.0
          end_time = Time.now.sys + sleep_time
          until (Time.now.sys >= end_time)
            sleep(0.01)
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

  @@instance = nil
  @@id = nil
  @@message_log = nil
  @@run_thread = nil
  @@breakpoints = {}
  @@step_mode = false
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
  @@output_sleeper = Cosmos::Sleeper.new
  @@limits_sleeper = Cosmos::Sleeper.new
  @@cancel_output = false
  @@cancel_limits = false

  def self.message_log(id = @@id)
    @@message_log ||= Cosmos::MessageLog.new("sr_#{id}", Rails.root.join('log').to_s)
  end

  def message_log
    self.class.message_log(@id)
  end

  def self.all
    redis = Redis.new(url: ActionCable.server.config.cable["url"])
    array = redis.smembers('running-scripts')
    items = []
    array.each do |member|
      items << JSON.parse(member)
    end
    items.sort {|a,b| b['id'] <=> a['id']}
  end

  def self.find(id)
    redis = Redis.new(url: ActionCable.server.config.cable["url"])
    result = redis.get("running-script:#{id}").to_s
    if result.length > 0
      JSON.parse(result)
    else
      return nil
    end
  end

  def self.spawn(name, bucket = nil)
    bucket ||= Script::DEFAULT_BUCKET_NAME
    runner_path = Rails.root.join('scripts/run_script.rb')
    redis = Redis.new(url: ActionCable.server.config.cable["url"])
    id = redis.incr('running-script-id')
    if RUBY_ENGINE != 'ruby'
      ruby_process_name = 'jruby'
    else
      ruby_process_name = 'ruby'
    end
    start_time = Time.now
    process = ChildProcess.build(ruby_process_name, runner_path.to_s, id.to_s, name, bucket)
    process.io.inherit! # Helps with debugging
    process.cwd = Rails.root.join('scripts').to_s
    process.start
    details = { id: id, name: name, bucket: bucket, start_time: start_time.to_s}
    redis.sadd('running-scripts', details.to_json)
    details[:hostname] = Socket.gethostname
    details[:pid] = process.pid
    details[:state] = :spawning
    details[:line_no] = 1
    details[:update_time] = start_time.to_s
    redis.set("running-script:#{id}", details.to_json)
    id
  end

  def initialize(id, name, bucket = nil)
    bucket ||= Script::DEFAULT_BUCKET_NAME
    @id = id
    @@id = id
    @filename = name
    @bucket = bucket
    @user_input = ''

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
    initialize_variables()

    # Redirect $stdout and $stderr
    redirect_io()

    mark_breakpoints(@filename)

    @name = name
    @state = :init

    # Get details from redis
    redis = Redis.new(url: ActionCable.server.config.cable["url"])
    begin
      details = redis.get("running-script:#{id}")
      if details
        @details = JSON.parse(details)
      else
        # Create as much details as we know
        @details = { id: @id, name: @filename, bucket: @bucket }
      end
    end

    # Update details in redis
    @details[:hostname] = Socket.gethostname
    @details[:state] = @state
    @details[:line_no] = 1
    @details[:update_time] = Time.now.to_s
    redis.set("running-script:#{id}", @details.to_json)

    # Retrieve file
    @body = ::Script.body(name, bucket)
    ActionCable.server.broadcast("running-script-channel:#{@id}", { type: :file, filename: @filename, bucket: bucket, text: @body })
  end

  def start
    run()
  end

  def go
    @go    = true
    @pause = false unless @@step_mode
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
      Cosmos.kill_thread(nil, @@run_thread)
      @@run_thread = nil
    end
  end

  def stop?
    @stop
  end

  def as_json(*args)
    { id: @id, state: @state, filename: @current_filename, line_no: @current_line_no }
  end

  # Private methods

  def initialize_variables
    @@error = nil
    @go = false
    if @@step_mode
      @pause = true
    else
      @pause = false
    end
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
    @@message_log.stop if @@message_log
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

  def allow_start=(value)
    @allow_start = value
  end

  def self.instance
    @@instance
  end

  def self.instance=(value)
    @@instance = value
  end

  def self.step_mode
    @@step_mode
  end

  def self.step_mode=(value)
    @@step_mode = value
    if self.instance
      if value
        self.instance.pause
      else
        self.instance.go
      end
    end
  end

  def self.line_delay
    @@line_delay
  end

  def self.line_delay=(value)
    @@line_delay = value
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
      puts Time.now.sys.formatted + " (SCRIPTRUNNER): "  + "Most recent exception:\n" + @@error.formatted
    end
  end

  def text
    #@script.toPlainText.gsub("\r", '')
    @body
  end

  def set_text(text, filename = '')
    unless running?()
      #@script.setPlainText(text)
      #@script.stop_highlight
      @filename = filename
      #@script.filename = unique_filename()
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
    #@realtime_button_bar.start_button.setText('Skip')
    #@realtime_button_bar.pause_button.setDisabled(true)
  end

  def enable_retry
    #@realtime_button_bar.start_button.setText('Go')
    #@realtime_button_bar.pause_button.setDisabled(false)
  end

  def run
    unless self.class.running?()
      run_text(@body)
    end
  end

  def run_and_close_on_complete(text_binding = nil)
    run_text(@body, 0, text_binding, true)
  end

  def self.instrument_script(text, filename, bucket, mark_private = false)
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
                                        bucket,
                                        mark_private)

    raise Cosmos::StopScript if @cancel_instrumentation
    instrumented_text
  end

  def self.instrument_script_implementation(ruby_lex_utils,
                                            comments_removed_text,
                                            num_lines,
                                            filename,
                                            bucket,
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
          "RunningScript.instance.pre_line_instrumentation('#{filename}', '#{bucket}', #{line_no}); "

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
            instrumented_line = "RunningScript.instance.pre_line_instrumentation('#{filename}', '#{bucket}', #{line_no}); " + segment
          end
        else
          instrumented_line = segment
        end
      end

      instrumented_text << instrumented_line

      #progress_dialog.set_overall_progress(line_no / num_lines) if progress_dialog and line_no
    end
    instrumented_text
  end

  def pre_line_instrumentation(filename, bucket, line_number)
    @current_filename = filename
    @current_line_number = line_number
    if @use_instrumentation
      # Clear go
      @go = false

      # Handle stopping mid-script if necessary
      raise Cosmos::StopScript if @stop

      # Handle needing to change tabs
      handle_potential_tab_change(filename, bucket)

      # Adjust line number for offset in main script
      line_number = line_number + @line_offset # if @active_script.object_id == @script.object_id
      detail_string = nil
      if filename
        detail_string = File.basename(filename) << ':' << line_number.to_s
      end
      Cosmos::Logger.detail_string = detail_string

      ActionCable.server.broadcast("running-script-channel:#{@id}", { type: :line, filename: @current_filename, line_no: @current_line_number, state: :running })

      # Handle pausing the script
      handle_pause(filename, line_number)

      # Handle delay between lines
      handle_line_delay()
    end
  end

  def post_line_instrumentation(filename, line_number)
    if @use_instrumentation
      line_number = line_number + @line_offset #if @active_script.object_id == @script.object_id
      handle_output_io(filename, line_number)
    end
  end

  def exception_instrumentation(error, filename, line_number)
    if error.class == Cosmos::StopScript || error.class == Cosmos::SkipTestCase || !@use_instrumentation
      raise error
    elsif !error.eql?(@@error)
      line_number = line_number + @line_offset #if @active_script.object_id == @script.object_id
      handle_exception(error, false, filename, line_number)
    end
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

  ######################################
  # Implement the breakpoint callbacks from the RubyEditor
  ######################################
  # def breakpoint_set(line)
  #   # Check for blank and comment lines which can't have a breakpoint.
  #   # There are other un-instrumentable lines which don't support breakpoints
  #   # but this is the most common and is an easy check.
  #   # Note: line is 1 based but @script.get_line is zero based so subtract 1
  #   text = @active_script.get_line(line - 1)
  #   if text && (text.strip.empty? || text.strip[0] == '#')
  #     @active_script.clear_breakpoint(line) # Immediately clear it
  #   else
  #     ScriptRunnerFrame.set_breakpoint(current_tab_filename(), line)
  #   end
  # end

  # def breakpoint_cleared(line)
  #   ScriptRunnerFrame.clear_breakpoint(current_tab_filename(), line)
  # end

  # def breakpoints_cleared
  #   ScriptRunnerFrame.clear_breakpoints(current_tab_filename())
  # end

  # ##################################################################################
  # # Implement Script functionality in the frame (run selection, run from cursor, etc
  # ##################################################################################
  # def run_selection
  #   unless self.class.running?()
  #     selection = @script.selected_lines
  #     if selection
  #       start_line_number = @script.selection_start_line
  #       end_line_number   = @script.selection_end_line
  #       scriptrunner_puts "Running script lines #{start_line_number+1}-#{end_line_number+1}: #{File.basename(@filename)}"
  #       handle_output_io()
  #       run_text(selection, start_line_number)
  #     end
  #   end
  # end

  # def run_selection_while_paused
  #   current_script = @tab_book.widget(@tab_book.currentIndex)
  #   selection = current_script.selected_lines
  #   if selection
  #     start_line_number = current_script.selection_start_line
  #     end_line_number   = current_script.selection_end_line
  #     scriptrunner_puts "Debug: Running selected lines #{start_line_number+1}-#{end_line_number+1}: #{@tab_book.tabText(@tab_book.currentIndex)}"
  #     handle_output_io()
  #     dialog = ScriptRunnerDialog.new(self, 'Executing Selected Lines While Paused')
  #     dialog.execute_text_and_close_on_complete(selection, @script_binding)
  #     handle_output_io()
  #   end
  # end

  # def run_from_cursor
  #   unless self.class.running?()
  #     line_number = @script.selection_start_line
  #     text = @script.toPlainText.split("\n")[line_number..-1].join("\n")
  #     scriptrunner_puts "Running script from line #{line_number}: #{File.basename(@filename)}"
  #     handle_output_io()
  #     run_text(text, line_number)
  #   end
  # end

  # def ruby_syntax_check_selection
  #   unless self.class.running?()
  #     selection = @script.selected_lines
  #     ruby_syntax_check_text(selection) if selection
  #   end
  # end

  # def ruby_syntax_check_text(selection = nil)
  #   unless self.class.running?()
  #     selection = text() unless selection
  #     check_process = IO.popen("ruby -c -rubygems 2>&1", 'r+')
  #     check_process.write("require 'cosmos'; require 'cosmos/script'; " + selection)
  #     check_process.close_write
  #     results = check_process.gets
  #     check_process.close
  #     if results
  #       if results =~ /Syntax OK/
  #         Qt::MessageBox.information(self, 'Syntax Check Successful', results)
  #       else
  #         # Results is a string like this: ":2: syntax error ..."
  #         # Normally the procedure comes before the first colon but since we
  #         # are writing to the process this is blank so we throw it away
  #         _, line_no, error = results.split(':')
  #         Qt::MessageBox.warning(self,
  #                                 'Syntax Check Failed',
  #                                 "Error on line #{line_no}: #{error.strip}")
  #       end
  #     else
  #       Qt::MessageBox.critical(self,
  #                               'Syntax Check Exception',
  #                               'Ruby syntax check unexpectedly returned nil')
  #     end
  #   end
  # end

  # def mnemonic_check_selection
  #   unless self.class.running?()
  #     selection = @script.selected_lines
  #     mnemonic_check_text(selection, @script.selection_start_line+1) if selection
  #   end
  # end

  # def mnemonic_check_text(text, start_line_number = 1)
  #   results = []
  #   line_number = start_line_number
  #   text.each_line do |line|
  #     if line =~ /\(/
  #       result = nil
  #       keyword = line.split('(')[0].split[-1]
  #       if CMD_KEYWORDS.include? keyword
  #         result = mnemonic_check_cmd_line(keyword, line_number, line)
  #       elsif TLM_KEYWORDS.include? keyword
  #         result = mnemonic_check_tlm_line(keyword, line_number, line)
  #       elsif SET_TLM_KEYWORDS.include? keyword
  #         result = mnemonic_check_set_tlm_line(keyword, line_number, line)
  #       elsif CHECK_KEYWORDS.include? keyword
  #         result = mnemonic_check_check_line(keyword, line_number, line)
  #       end
  #       results << result if result
  #     end
  #     line_number += 1
  #   end

  #   if results.empty?
  #     Qt::MessageBox.information(self,
  #                                 'Mnemonic Check Successful',
  #                                 'Mnemonic Check Found No Errors')
  #   else
  #     dialog = Qt::Dialog.new(self) do |box|
  #       box.setWindowTitle('Mnemonic Check Failed')
  #       text = Qt::PlainTextEdit.new
  #       text.setReadOnly(true)
  #       text.setPlainText(results.join("\n"))
  #       frame = Qt::VBoxLayout.new(box)
  #       ok = Qt::PushButton.new('Ok')
  #       ok.setDefault(true)
  #       ok.connect(SIGNAL('clicked(bool)')) { box.accept }
  #       frame.addWidget(text)
  #       frame.addWidget(ok)
  #     end
  #     dialog.exec
  #     dialog.dispose
  #   end
  # end

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
      Logger.error("Error Connecting to Command and Telemetry Server")
    else
      Logger.error(error.class.to_s.split('::')[-1] + ' : ' + error.message)
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

  # def hide_debug
  #   # Since we're disabling debug, clear the breakpoints and disable them
  #   ScriptRunnerFrame.clear_breakpoints()
  #   @script.clear_breakpoints
  #   @script.enable_breakpoints = false
  #   if @tab_book_shown
  #     if @tab_book.count > 0
  #       (0..(@tab_book.count - 1)).each do |index|
  #         @tab_book.widget(index).enable_breakpoints = false
  #       end
  #     end
  #   end
  #   @realtime_button_bar.step_button.setHidden(true)
  #   # Remove the debug frame
  #   @bottom_frame.layout.takeAt(@bottom_frame.layout.count - 1) if @debug_frame
  #   @debug_frame.removeAll
  #   @debug_frame.dispose
  #   @debug_frame = nil

  #   # If step mode was previously active then pause the script so it doesn't
  #   # just take off when we end the debugging session
  #   if @@step_mode
  #     pause()
  #     @@step_mode = false
  #   end
  # end

  # def self.set_breakpoint(filename, line_number)
  #   @@breakpoints[filename] ||= {}
  #   @@breakpoints[filename][line_number] = true
  # end

  # def self.clear_breakpoint(filename, line_number)
  #   @@breakpoints[filename] ||= {}
  #   @@breakpoints[filename].delete(line_number) if @@breakpoints[filename][line_number]
  # end

  # def self.clear_breakpoints(filename = nil)
  #   if filename == nil or filename.empty?
  #     @@breakpoints = {}
  #   else
  #     @@breakpoints.delete(filename)
  #   end
  # end

  # def clear_breakpoints
  #   ScriptRunnerFrame.clear_breakpoints(unique_filename())
  # end

  # def select_tab_and_destroy_tabs_after_index(index)
  #   Qt.execute_in_main_thread(true) do
  #     if @tab_book_shown
  #       @tab_book.setCurrentIndex(index)
  #       @active_script = @tab_book.widget(@tab_book.currentIndex)

  #       first_to_remove = index + 1
  #       last_to_remove  = @call_stack.length - 1

  #       last_to_remove.downto(first_to_remove) do |tab_index|
  #         tab = @tab_book.widget(tab_index)
  #         @tab_book.removeTab(tab_index)
  #         tab.dispose
  #       end

  #       @call_stack = @call_stack[0..index]
  #       @current_file = @call_stack[index]
  #     end
  #   end
  # end

  # def toggle_disconnect(config_file, ask_for_config_file = true)
  #   dialog = Qt::Dialog.new(self, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
  #   dialog.setWindowTitle("Disconnect Settings")
  #   dialog_layout = Qt::VBoxLayout.new
  #   dialog_layout.addWidget(Qt::Label.new("Targets checked will be disconnected."))

  #   all_targets = {}
  #   set_clear_layout = Qt::HBoxLayout.new
  #   check_all = Qt::PushButton.new("Check All")
  #   check_all.setAutoDefault(false)
  #   check_all.setDefault(false)
  #   check_all.connect(SIGNAL('clicked()')) do
  #     all_targets.each do |target, checkbox|
  #       checkbox.setChecked(true)
  #     end
  #   end
  #   set_clear_layout.addWidget(check_all)
  #   clear_all = Qt::PushButton.new("Clear All")
  #   clear_all.connect(SIGNAL('clicked()')) do
  #     all_targets.each do |target, checkbox|
  #       checkbox.setChecked(false)
  #     end
  #   end
  #   set_clear_layout.addWidget(clear_all)
  #   dialog_layout.addLayout(set_clear_layout)

  #   scroll = Qt::ScrollArea.new
  #   target_widget = Qt::Widget.new
  #   scroll.setWidget(target_widget)
  #   target_layout = Qt::VBoxLayout.new(target_widget)
  #   target_layout.setSizeConstraint(Qt::Layout::SetMinAndMaxSize)
  #   scroll.setSizePolicy(Qt::SizePolicy::Preferred, Qt::SizePolicy::Expanding)
  #   scroll.setWidgetResizable(true)

  #   existing = get_disconnected_targets()
  #   System.targets.keys.each do |target|
  #     check_layout = Qt::HBoxLayout.new
  #     check_label = Qt::CheckboxLabel.new(target)
  #     checkbox = Qt::CheckBox.new
  #     all_targets[target] = checkbox
  #     if existing
  #       checkbox.setChecked(existing && existing.include?(target))
  #     else
  #       checkbox.setChecked(true)
  #     end
  #     check_label.setCheckbox(checkbox)
  #     check_layout.addWidget(checkbox)
  #     check_layout.addWidget(check_label)
  #     check_layout.addStretch
  #     target_layout.addLayout(check_layout)
  #   end
  #   dialog_layout.addWidget(scroll)

  #   if ask_for_config_file
  #     chooser = FileChooser.new(self, "Config File", config_file, 'Select',
  #                               File.dirname(config_file))
  #     chooser.callback = lambda do |filename|
  #       chooser.filename = filename
  #     end
  #     dialog_layout.addWidget(chooser)
  #   end

  #   button_layout = Qt::HBoxLayout.new
  #   ok = Qt::PushButton.new("Ok")
  #   ok.setAutoDefault(true)
  #   ok.setDefault(true)
  #   targets = []
  #   ok.connect(SIGNAL('clicked()')) do
  #     all_targets.each do |target, checkbox|
  #       targets << target if checkbox.isChecked
  #     end
  #     dialog.accept()
  #   end
  #   button_layout.addWidget(ok)
  #   cancel = Qt::PushButton.new("Cancel")
  #   cancel.connect(SIGNAL('clicked()')) do
  #     dialog.reject()
  #   end
  #   button_layout.addWidget(cancel)
  #   dialog_layout.addLayout(button_layout)

  #   dialog.setLayout(dialog_layout)
  #   my_parent = self.parent
  #   while my_parent.parent
  #     my_parent = my_parent.parent
  #   end
  #   if dialog.exec == Qt::Dialog::Accepted
  #     if targets.empty?
  #       clear_disconnected_targets()
  #       my_parent.statusBar.showMessage("")
  #       self.setPalette(Qt::Palette.new(Cosmos::DEFAULT_PALETTE))
  #     else
  #       config_file = chooser.filename
  #       my_parent.statusBar.showMessage("Targets disconnected: #{targets.join(" ")}")
  #       self.setPalette(Qt::Palette.new(Cosmos::RED_PALETTE))
  #       Splash.execute(self) do |splash|
  #         ConfigParser.splash = splash
  #         splash.message = "Initializing Command and Telemetry Server"
  #         set_disconnected_targets(targets, targets.length == all_targets.length, config_file)
  #         ConfigParser.splash = nil
  #       end
  #     end
  #   end
  #   dialog.dispose
  #   config_file
  # end

  def current_backtrace
    trace = []
    if @@run_thread
      temp_trace = @@run_thread.backtrace
      temp_trace.each do |line|
        next if line.include?(Cosmos::PATH)    # Ignore COSMOS internals
        next if line.include?('lib/ruby/gems') # Ignore system gems
        trace << line
      end
    end
    trace
  end

  def scriptrunner_puts(string, color = 'BLACK')
    line_to_write = Time.now.sys.formatted + " (SCRIPTRUNNER): "  + string
    ActionCable.server.broadcast("running-script-channel:#{@id}", { type: :output, line: line_to_write, color: color })
  end

  def handle_output_io(filename = @current_filename, line_number = @current_line_number)
    @output_time = Time.now.sys
    if @output_io.string[-1..-1] == "\n"
      time_formatted = Time.now.sys.formatted
      lines_to_write = ''
      out_line_number = line_number.to_s
      out_filename = File.basename(filename) if filename

      # Build each line to write
      string = @output_io.string.clone
      @output_io.string = @output_io.string[string.length..-1]
      line_count = 0
      string.each_line do |out_line|
        color = 'BLACK'
        if out_line[0..1] == '20' and out_line[10] == ' ' and out_line[23..24] == ' ('
          line_to_write = out_line
        else
          if filename
            line_to_write = time_formatted + " (#{out_filename}:#{out_line_number}): "  + out_line
          else
            line_to_write = time_formatted + " (SCRIPTRUNNER): "  + out_line
            color = 'BLUE'
          end
        end

        ActionCable.server.broadcast("running-script-channel:#{@id}", { type: :output, line: line_to_write, color: color })
        lines_to_write << line_to_write

        line_count += 1
        if line_count > @stdout_max_lines
          out_line = "ERROR: Too much written to stdout.  Truncating output to #{@stdout_max_lines} lines.\n"
          if filename
            line_to_write = time_formatted + " (#{out_filename}:#{out_line_number}): "  + out_line
          else
            line_to_write = time_formatted + " (SCRIPTRUNNER): "  + out_line
          end

          ActionCable.server.broadcast("running-script-channel:#{@id}", { type: :output, line: line_to_write, color: 'RED' })
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

  def wait_for_go_or_stop(error = nil)
    @go = false
    sleep(0.01) until @go or @stop
    @go = false
    mark_running()
    raise Cosmos::StopScript if @stop
    raise error if error and !@continue_after_error
  end

  def wait_for_go_or_stop_or_retry(error = nil)
    @go = false
    sleep(0.01) until @go or @stop or @retry_needed
    @go = false
    mark_running()
    raise Cosmos::StopScript if @stop
    raise error if error and !@continue_after_error
  end

  def mark_running
    @state = :running
    ActionCable.server.broadcast("running-script-channel:#{@id}", { type: :line, filename: @current_filename, line_no: @current_line_number, state: :running })
  end

  def mark_paused
    ActionCable.server.broadcast("running-script-channel:#{@id}", { type: :line, filename: @current_filename, line_no: @current_line_number, state: :paused })
  end

  def mark_error
    ActionCable.server.broadcast("running-script-channel:#{@id}", { type: :line, filename: @current_filename, line_no: @current_line_number, state: :error })
  end

  def mark_stopped
    ActionCable.server.broadcast("running-script-channel:#{@id}", { type: :line, filename: @current_filename, line_no: @current_line_number, state: :stopped })
    ActionCable.server.broadcast("cmd-running-script-channel:#{@id}", "shutdown")
  end

  def mark_breakpoint
    ActionCable.server.broadcast("running-script-channel:#{@id}", { type: :line, filename: @current_filename, line_no: @current_line_number, state: :breakpoint })
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
          scriptrunner_puts("Starting script: #{File.basename(@filename)}")
          #targets = get_disconnected_targets()
          #if targets
          #  scriptrunner_puts("DISCONNECTED targets: #{targets.join(',')}")
          #end
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
            instrumented_script = self.class.instrument_script(text, @filename, @bucket, false)
          else
            instrumented_script = self.class.instrument_script(text, @filename, @bucket, true)
          end
          @top_level_instrumented_cache = [text, line_offset, @filename, instrumented_script]
        end

        # Execute the script with warnings disabled
        Cosmos.disable_warnings do
          @pre_line_time = Time.now.sys
          Cosmos.set_working_dir do
            if text_binding
              eval(instrumented_script, text_binding, @filename, 1)
            else
              Object.class_eval(instrumented_script, @filename, 1)
            end
          end
        end

        scriptrunner_puts "Script completed: #{File.basename(@filename)}" unless close_on_complete
        handle_output_io()

      rescue Exception => error
        if error.class == Cosmos::StopScript or error.class == Cosmos::SkipTestCase
          scriptrunner_puts "Script stopped: #{File.basename(@filename)}"
          handle_output_io()
        else
          uncaught_exception = true
          filename, line_number = error.source
          handle_exception(error, true, filename, line_number)
          scriptrunner_puts "Exception in Control Statement - Script stopped: #{File.basename(@filename)}"
          handle_output_io()
          ActionCable.server.broadcast("running-script-channel:#{@id}", { type: :line, filename: @current_filename, line_no: @current_line_number, state: :stopped_exception })
        end
      ensure
        # Stop Capturing STDOUT and STDERR
        # Check for remove_stream because if the tool is quitting the
        # Cosmos::restore_io may have been called which sets $stdout and
        # $stderr to the IO constant
        $stdout.remove_stream(@output_io) if $stdout.respond_to? :remove_stream
        $stderr.remove_stream(@output_io) if $stderr.respond_to? :remove_stream

        # Clear run thread and instance to indicate we are no longer running
        @@instance = saved_instance
        @@run_thread = saved_run_thread
        @active_script = @script
        @script_binding = nil
        @current_filename = nil
        @current_line_number = 0
        if @@limits_monitor_thread and not @@instance
          @@cancel_limits = true
          @@limits_sleeper.cancel
          Cosmos.kill_thread(self, @@limits_monitor_thread)
          @@limits_monitor_thread = nil
        end
        if @@output_thread and not @@instance
          @@cancel_output = true
          @@output_sleeper.cancel
          Cosmos.kill_thread(self, @@output_thread)
          @@output_thread = nil
        end

        mark_stopped()
      end
    end
  end

  def handle_potential_tab_change(filename, bucket = nil)
    bucket ||= ::Script::DEFAULT_BUCKET_NAME

    # Make sure the correct file is shown in script runner
    if @current_file != filename
      #Qt.execute_in_main_thread(true) do
        if @call_stack.include?(filename)
          index = @call_stack.index(filename)
          #select_tab_and_destroy_tabs_after_index(index)
        else # new file
          # Create new tab
          #new_script = create_ruby_editor()
          #new_script.filename = filename
          #@tab_book.addTab(new_script, '  ' + File.basename(filename) + '  ')

          @call_stack.push(filename.dup)

          # Switch to new tab
          #@tab_book.setCurrentIndex(@tab_book.count - 1)
          #@active_script = new_script
          load_file_into_script(filename, bucket)
          #new_script.setReadOnly(true)
        end

        @current_file = filename
      #end
    end
  end

  def show_active_tab
    #@tab_book.setCurrentIndex(@call_stack.length - 1) if @tab_book_shown
  end

  def handle_pause(filename, line_number)
    bkpt_filename = ''
    #Qt.execute_in_main_thread(true) {bkpt_filename = @active_script.filename}
    breakpoint = false
    breakpoint = true if @@breakpoints[bkpt_filename] and @@breakpoints[bkpt_filename][line_number]

    filename = File.basename(filename)
    if @pause
      @pause = false unless @@step_mode
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
      #if Qt::MessageBox.warning(self, "Warning", "If an error occurs, the script will not pause and will run to completion. Continue?", Qt::MessageBox::Yes | Qt::MessageBox::No, Qt::MessageBox::Yes) == Qt::MessageBox::No
      #  return false
      #end
    end
    true
  end

  # def handle_step_button
  #   scriptrunner_puts "User pressed #{@realtime_button_bar.step_button.text.strip}"
  #   pause()
  #   @@step_mode = true
  #   handle_start_go_button(step = true)
  # end

  # def handle_start_go_button(step = false)
  #   unless step
  #     scriptrunner_puts "User pressed #{@realtime_button_bar.start_button.text.strip}"
  #     @@step_mode = false
  #   end
  #   handle_output_io()
  #   @realtime_button_bar.start_button.clear_focus()

  #   if running?()
  #     show_active_tab()
  #     go()
  #   else
  #     if @allow_start
  #       run() if continue_without_pausing_on_errors?()
  #     end
  #   end
  # end

  # def handle_pause_retry_button
  #   scriptrunner_puts "User pressed #{@realtime_button_bar.pause_button.text.strip}"
  #   handle_output_io()
  #   @realtime_button_bar.pause_button.clear_focus()
  #   show_active_tab() if running?
  #   if @realtime_button_bar.pause_button.text.to_s == 'Pause'
  #     pause()
  #   else
  #     retry_needed()
  #   end
  # end

  # def handle_stop_button
  #   scriptrunner_puts "User pressed #{@realtime_button_bar.stop_button.text.strip}"
  #   handle_output_io()
  #   @realtime_button_bar.stop_button.clear_focus()

  #   if @stop
  #     # If we're already stopped and they click Stop again, kill the run
  #     # thread. This will break any ruby sleeps or other code blocks.
  #     ScriptRunnerFrame.stop!
  #     handle_output_io()
  #   else
  #     @stop = true
  #   end
  #   if !running?()
  #     # Stop highlight if there was a red syntax error
  #     @script.stop_highlight
  #   end
  # end

  def handle_exception(error, fatal, filename = nil, line_number = 0)
    scriptrunner_puts(error.message, 'RED')
    @exceptions ||= []
    @exceptions << error
    @@error = error

    if error.class == DRb::DRbConnError
      Cosmos::Logger.error("Error Connecting to Command and Telemetry Server")
    elsif error.class == Cosmos::CheckError
      Cosmos::Logger.error(error.message)
    else
      Cosmos::Logger.error(error.class.to_s.split('::')[-1] + ' : ' + error.message)
    end
    Cosmos::Logger.error(error.backtrace.join("\n")) # if @@show_backtrace
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

  # # Right click context_menu for the script
  # def context_menu(point)
  #   # Only show context menu if not running or paused.  Otherwise will segfault if current tab goes away while menu
  #   # is shown
  #   if not self.class.running? or (running?() and @realtime_button_bar.state != 'Running')
  #     if @tab_book_shown
  #       current_script = @tab_book.widget(@tab_book.currentIndex)
  #     else
  #       current_script = @script
  #     end
  #     menu = current_script.context_menu(point)
  #     menu.addSeparator()
  #     if not self.class.running?
  #       exec_selected_action = Qt::Action.new("Execute Selected Lines", self)
  #       exec_selected_action.statusTip = "Execute the selected lines as a standalone script"
  #       exec_selected_action.connect(SIGNAL('triggered()')) { run_selection() }
  #       menu.addAction(exec_selected_action)

  #       exec_cursor_action = Qt::Action.new("Execute From Cursor", self)
  #       exec_cursor_action.statusTip = "Execute the script starting at the line containing the cursor"
  #       exec_cursor_action.connect(SIGNAL('triggered()')) { run_from_cursor() }
  #       menu.addAction(exec_cursor_action)

  #       menu.addSeparator()

  #       if RUBY_VERSION.split('.')[0].to_i > 1
  #         syntax_action = Qt::Action.new("Ruby Syntax Check Selected Lines", self)
  #         syntax_action.statusTip = "Check the selected lines for valid Ruby syntax"
  #         syntax_action.connect(SIGNAL('triggered()')) { ruby_syntax_check_selection() }
  #         menu.addAction(syntax_action)
  #       end

  #       mnemonic_action = Qt::Action.new("Mnemonic Check Selected Lines", self)
  #       mnemonic_action.statusTip = "Check the selected lines for valid targets, packets, mnemonics and parameters"
  #       mnemonic_action.connect(SIGNAL('triggered()')) { mnemonic_check_selection() }
  #       menu.addAction(mnemonic_action)

  #     elsif running?() and @realtime_button_bar.state != 'Running'
  #       exec_selected_action = Qt::Action.new("Execute Selected Lines While Paused", self)
  #       exec_selected_action.statusTip = "Execute the selected lines as a standalone script"
  #       exec_selected_action.connect(SIGNAL('triggered()')) { run_selection_while_paused() }
  #       menu.addAction(exec_selected_action)
  #     end
  #     menu.exec(current_script.mapToGlobal(point))
  #     menu.dispose
  #   end
  # end

  def load_file_into_script(filename, bucket = nil)
    bucket ||= ::Script::DEFAULT_BUCKET_NAME
    cached = @@file_cache[filename]
    if cached
      #@active_script.setPlainText(cached.gsub("\r", ''))
      @body = cached
      ActionCable.server.broadcast("running-script-channel:#{@id}", { type: :file, filename: filename, text: @body })
    else
      text = ::Script.body(filename, bucket)
      @@file_cache[filename] = text
      @body = text
      ActionCable.server.broadcast("running-script-channel:#{@id}", { type: :file, filename: filename, bucket: bucket, text: @body })
    end
    mark_breakpoints(filename)

    #@active_script.stop_highlight
  end

  def mark_breakpoints(filename)
    breakpoints = @@breakpoints[filename]
    if breakpoints
      breakpoints.each do |line_number, present|
        #@active_script.add_breakpoint(line_number) if present
      end
    end
  end

  def redirect_io
    # Redirect Standard Output and Standard Error
    $stdout = Cosmos::Stdout.instance
    $stderr = Cosmos::Stderr.instance

    # Disable outputting to default io file descriptors
    #$stdout.remove_default_io
    #$stderr.remove_default_io

    Cosmos::Logger.level = Cosmos::Logger::INFO
    Cosmos::Logger::INFO_SEVERITY_STRING.replace('')
    Cosmos::Logger::WARN_SEVERITY_STRING.replace('<Y> WARN:')
    Cosmos::Logger::ERROR_SEVERITY_STRING.replace('<R> ERROR:')
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
    @@output_sleeper = Cosmos::Sleeper.new
    begin
      loop do
        break if @@cancel_output
        handle_output_io() if (Time.now.sys - @output_time) > 5.0
        break if @@cancel_output
        break if @@output_sleeper.sleep(1.0)
      end # loop
    rescue => error
      #Qt.execute_in_main_thread(true) do
      #  ExceptionDialog.new(self, error, "Output Thread")
      #end
    end
  end

  def limits_monitor_thread
    @@cancel_limits = false
    @@limits_sleeper = Cosmos::Sleeper.new
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
                msg = "#{target_name} #{packet_name} #{item_name} is #{new_limits_state.to_s}"
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
              msg = "#{target_name} #{packet_name} #{item_name} is #{new_limits_state.to_s}"
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
      #Qt.execute_in_main_thread(true) do
      #  ExceptionDialog.new(self, error, "Limits Monitor Thread")
      #end
    end
  ensure
    begin
      unsubscribe_limits_events(queue_id) if queue_id
    rescue
      # Oh Well
    end
  end

end