# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/script'
require 'cosmos/gui/utilities/script_module_gui'
require 'cosmos/gui/dialogs/splash'
require 'cosmos/gui/dialogs/exception_dialog'
require 'cosmos/gui/text/completion'
require 'cosmos/gui/text/completion_line_edit'
require 'cosmos/gui/text/ruby_editor'
require 'cosmos/gui/dialogs/progress_dialog'
require 'cosmos/gui/widgets/realtime_button_bar'
require 'cosmos/gui/dialogs/find_replace_dialog'
require 'cosmos/gui/choosers/file_chooser'
require 'cosmos/io/stdout'
require 'cosmos/io/stderr'

module Cosmos

  Cosmos.disable_warnings do
    module Script
      def prompt_for_script_abort
        ScriptRunnerFrame.instance.perform_pause
        return false # Not aborted - Retry
      end
    end
  end

  # Create a dialog with an embedded ScriptRunnerFrame used to execute
  # a snippet of code while the main script is paused.
  class ScriptRunnerDialog < Qt::Dialog
    attr_reader :script_runner_frame

    def initialize(parent,
                   title,
                   default_tab_text = 'Untitled')
      super(parent)
      setWindowTitle(title)
      setMinimumWidth(parent.width * 0.8)
      setMinimumHeight(parent.height * 0.6)

      # Create script runner frame
      @script_runner_frame = ScriptRunnerFrame.new(self, default_tab_text)
      layout = Qt::VBoxLayout.new
      layout.addWidget(@script_runner_frame)
      setLayout(layout)
    end

    # Executes the given text and closes when complete
    def execute_text_and_close_on_complete(text, text_binding = nil)
      @script_runner_frame.set_text(text)
      @script_runner_frame.run_and_close_on_complete(text_binding)
      exec
      dispose
    end

    def reject
      # Don't allow the dialog to close if we're running
      return if @script_runner_frame.running?
      super
    end
  end

  # Frame within ScriptRunner and TestRunner that handles instrumenting the
  # script and running it. This includes handling all the user interation and
  # how to run, step, pause, and stop a script.
  class ScriptRunnerFrame < Qt::Widget
    slots 'context_menu(const QPoint&)'
    slots 'undo_available(bool)'
    slots 'breakpoint_set(int)'
    slots 'breakpoint_cleared(int)'
    slots 'breakpoints_cleared()'
    signals 'undoAvailable(bool)'
    signals 'modificationChanged(bool)'

    CMD_KEYWORDS     = %w(cmd cmd_no_range_check cmd_no_hazardous_check cmd_no_checks)
    TLM_KEYWORDS     = %w(tlm tlm_raw tlm_formatted tlm_with_units limits_enabled? \
                          enable_limits disable_limits wait_tolerance wait_tolerance_raw \
                          check_tolerance check_tolerance_raw wait_check_tolerance \
                          wait_check_tolerance_raw)
    SET_TLM_KEYWORDS = %w(set_tlm set_tlm_raw override_tlm_raw normalize_tlm_raw)
    CHECK_KEYWORDS   = %w(check check_raw wait wait_raw wait_check wait_check_raw)

    INSTANCE_VARS = %w(__return_val close_on_complete error eval_error filename instrumented_script \
      line_number line_offset saved_instance saved_run_thread text text_binding uncaught_exception)

    attr_accessor :use_instrumentation
    attr_accessor :change_callback
    attr_accessor :run_callback
    attr_accessor :stop_callback
    attr_accessor :error_callback
    attr_accessor :pause_callback
    attr_reader :filename
    attr_accessor :continue_after_error
    attr_accessor :exceptions
    attr_accessor :script_binding
    attr_accessor :inline_return # Deprecated and unused - Here to prevent cache errors for old scripts
    attr_accessor :inline_return_params # Deprecated and unused - Here to prevent cache errors for old scripts
    attr_reader   :message_log
    attr_reader   :script_class
    attr_reader   :top_level_instrumented_cache
    attr_accessor :stdout_max_lines
    attr_reader   :script

    @@instance = nil
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
    @@output_sleeper = Sleeper.new
    @@limits_sleeper = Sleeper.new
    @@cancel_output = false
    @@cancel_limits = false
    @@file_number = 1
    @@default_font = Cosmos.get_default_font

    def initialize(parent, default_tab_text = 'Untitled')
      super(parent)
      @default_tab_text = '  ' + default_tab_text + '  '
      # Keep track of whether this frame has been fully initialized
      @initialized = false
      @debug_frame = nil

      # Keep track of a unique file number so we can differentiate untitled tabs
      @file_number = @@file_number
      @@file_number +=1
      @filename = ''

      @layout = Qt::VBoxLayout.new
      @layout.setContentsMargins(0,0,0,0)

      # Add Realtime Button Bar
      @realtime_button_bar = RealtimeButtonBar.new(self)
      @realtime_button_bar.state = 'Stopped'
      @realtime_button_bar.step_callback = method(:handle_step_button)
      @realtime_button_bar.start_callback = method(:handle_start_go_button)
      @realtime_button_bar.pause_callback = method(:handle_pause_retry_button)
      @realtime_button_bar.stop_callback  = method(:handle_stop_button)
      @layout.addWidget(@realtime_button_bar)

      # Create shortcuts to activate the RealtimeButtonBar actions
      step = Qt::Shortcut.new(Qt::KeySequence.new(Qt::Key_F10), self)
      self.connect(step, SIGNAL('activated()')) { handle_step_button() }
      start_go = Qt::Shortcut.new(Qt::KeySequence.new(Qt::Key_F5), self)
      self.connect(start_go, SIGNAL('activated()')) { handle_start_go_button() }
      pause_retry = Qt::Shortcut.new(Qt::KeySequence.new(Qt::Key_F6), self)
      self.connect(pause_retry, SIGNAL('activated()')) { handle_pause_retry_button() }
      stop = Qt::Shortcut.new(Qt::KeySequence.new(Qt::Key_F7), self)
      self.connect(stop, SIGNAL('activated()')) { handle_stop_button() }

      # Create a splitter to hold the script text area and the script output text area.
      @splitter = Qt::Splitter.new(Qt::Vertical, self)
      @layout.addWidget(@splitter)
      @top_widget = Qt::Widget.new(@splitter)
      @top_widget.setContentsMargins(0,0,0,0)
      @top_frame = Qt::VBoxLayout.new(@top_widget)
      @top_frame.setContentsMargins(0,0,0,0)

      # Add Initial Text Window
      @script = create_ruby_editor()
      @script.filename = unique_filename()
      @script.connect(SIGNAL('modificationChanged(bool)')) do |changed|
        emit modificationChanged(changed)
      end
      @top_frame.addWidget(@script)

      # Set self as the gui window to allow prompts and other popups to appear
      set_cmd_tlm_gui_window(self)

      # Add change handlers
      connect(@script,
              SIGNAL('undoAvailable(bool)'),
              self,
              SLOT('undo_available(bool)'))

      # Add Output Text
      @bottom_frame = Qt::Widget.new
      @bottom_layout = Qt::VBoxLayout.new
      @bottom_layout.setContentsMargins(0,0,0,0)
      @bottom_layout_label = Qt::Label.new("Script Output:")
      @bottom_layout.addWidget(@bottom_layout_label)
      @output = Qt::PlainTextEdit.new
      @output.setReadOnly(true)
      @output.setMaximumBlockCount(100)
      @bottom_layout.addWidget(@output)
      @bottom_frame.setLayout(@bottom_layout)
      @splitter.addWidget(@bottom_frame)
      @splitter.setStretchFactor(0,10)
      @splitter.setStretchFactor(1,1)

      setLayout(@layout)

      # Configure Variables
      @line_offset = 0
      @output_io = StringIO.new('', 'r+')
      @output_io_mutex = Mutex.new
      @change_callback = nil
      @run_callback = nil
      @stop_callback = nil
      @error_callback = nil
      @pause_callback = nil
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

      # Create Tabbook
      @tab_book = Qt::TabWidget.new
      @tab_book_shown = false

      @find_dialog = nil
      @replace_dialog = nil

      mark_breakpoints(@script.filename)
    end

    def unique_filename
      if @filename and !@filename.empty?
        return @filename
      else
        return @default_tab_text.strip + @file_number.to_s
      end
    end

    def current_tab_filename
      if @tab_book_shown
        return @tab_book.widget(@tab_book.currentIndex).filename
      else
        return @script.filename
      end
    end

    def create_ruby_editor
      # Add Initial Text Window
      script = RubyEditor.new(self, @@default_font)
      script.enable_breakpoints = true if @debug_frame
      connect(script,
              SIGNAL('breakpoint_set(int)'),
              self,
              SLOT('breakpoint_set(int)'))
      connect(script,
              SIGNAL('breakpoint_cleared(int)'),
              self,
              SLOT('breakpoint_cleared(int)'))
      connect(script,
              SIGNAL('breakpoints_cleared()'),
              self,
              SLOT('breakpoints_cleared()'))
      script.connect(SIGNAL('font_changed(QFont)')) do |font|
        # Remember changed fonts for future tabs
        @@default_font = font
      end

      # Add right click menu
      script.setContextMenuPolicy(Qt::CustomContextMenu)
      connect(script,
              SIGNAL('customContextMenuRequested(const QPoint&)'),
              self,
              SLOT('context_menu(const QPoint&)'))

      return script
    end

    def stop_message_log
      @message_log.stop if @message_log
      @message_log = nil
    end

    def filename=(filename)
      # Stop the message log so a new one will be created with the new filename
      stop_message_log()
      @filename = filename

      # Deal with breakpoints created under the previous filename.
      bkpt_filename = unique_filename()
      if @@breakpoints[bkpt_filename].nil?
        @@breakpoints[bkpt_filename] = @@breakpoints[@script.filename]
      end
      if bkpt_filename != @script.filename
        @@breakpoints.delete(@script.filename)
        @script.filename = bkpt_filename
      end
      mark_breakpoints(@script.filename)
    end

    def modified
      @script.document.isModified()
    end

    def modified=(bool)
      @script.document.setModified(bool)
    end

    def undo_available(bool)
      emit undoAvailable(bool)
    end

    def setFocus
      @script.setFocus
    end

    def active_script_highlight(color)
      Qt.execute_in_main_thread { @active_script.highlight_line(color) }
    end

    def allow_start=(value)
      @allow_start = value
      if @allow_start
        @realtime_button_bar.start_button.setEnabled(true)
      elsif not running?
        @realtime_button_bar.start_button.setEnabled(false)
        @script.setReadOnly(true)
      end
    end

    def clear
      self.set_text('')
      self.filename = ''
      @script.filename = unique_filename()
      self.modified = false
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
      @script.toPlainText.gsub("\r", '')
    end

    def set_text(text, filename = '')
      unless running?()
        @script.setPlainText(text)
        @script.stop_highlight
        @filename = filename
        @script.filename = unique_filename()
        mark_breakpoints(@script.filename)
      end
    end

    def set_text_from_file(filename)
      unless running?()
        @@file_cache[filename] = nil
        @@breakpoints[filename] = nil
        load_file_into_script(filename)
        @filename = filename
      end
    end

    def self.running?
      if @@run_thread then true else false end
    end

    def running?
      if @@instance == self and ScriptRunnerFrame.running?() then true else false end
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

    def self.stop!
      if @@run_thread
        Cosmos.kill_thread(nil, @@run_thread)
        @@run_thread = nil
      end
    end

    def stop?
      @stop
    end

    def retry_needed?
      @retry_needed
    end

    def retry_needed
      @retry_needed = true
    end

    def disable_retry
      @realtime_button_bar.start_button.setText('Skip')
      @realtime_button_bar.pause_button.setDisabled(true)
    end

    def enable_retry
      @realtime_button_bar.start_button.setText('Go')
      @realtime_button_bar.pause_button.setDisabled(false)
    end

    def run
      unless self.class.running?()
        run_text(@script.toPlainText)
      end
    end

    def run_and_close_on_complete(text_binding = nil)
      run_text(@script.toPlainText, 0, text_binding, true)
    end

    def self.instrument_script(text, filename, mark_private = false)
      if filename and !filename.empty?
        @@file_cache[filename] = text.clone
      end

      ruby_lex_utils = RubyLexUtils.new
      instrumented_text = ''

      Qt.execute_in_main_thread(true) do
        window = Qt::CoreApplication.instance.activeWindow
        @cancel_instrumentation = false
        ProgressDialog.execute(window, # parent
                               "Instrumenting: #{File.basename(filename.to_s)}",
                               500,    # width
                               100,    # height
                               true,   # show overall progress
                               false,  # don't show step progress
                               false,  # don't show text
                               false,  # don't show done
                               true) do |progress_dialog| # show cancel
          progress_dialog.cancel_callback = lambda { |dialog| @cancel_instrumentation = true; [true, false] }
          progress_dialog.enable_cancel_button
          comments_removed_text = ruby_lex_utils.remove_comments(text)
          num_lines = comments_removed_text.num_lines.to_f
          num_lines = 1 if num_lines < 1
          instrumented_text =
            instrument_script_implementation(ruby_lex_utils,
                                             comments_removed_text,
                                             num_lines,
                                             progress_dialog,
                                             filename,
                                             mark_private)
          progress_dialog.close_done
        end
      end

      Kernel.raise StopScript if @cancel_instrumentation or ProgressDialog.canceled?
      instrumented_text
    end

    def self.instrument_script_implementation(ruby_lex_utils,
                                              comments_removed_text,
                                              num_lines,
                                              progress_dialog,
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
          instrumented_line << "ScriptRunnerFrame.instance.script_binding = binding(); "\
            "ScriptRunnerFrame.instance.pre_line_instrumentation('#{filename}', #{line_no}); "

          # Add the actual line
          instrumented_line << "__return_val = "
          instrumented_line << segment
          instrumented_line.chomp!

          # Add postline instrumentation
          instrumented_line << "; ScriptRunnerFrame.instance.post_line_instrumentation('#{filename}', #{line_no}); "

          # Complete begin block to catch exceptions
          unless inside_begin
            instrumented_line << "rescue Exception => eval_error; "\
            "retry if ScriptRunnerFrame.instance.exception_instrumentation(eval_error, '#{filename}', #{line_no}); end; "
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
              instrumented_line = "ScriptRunnerFrame.instance.pre_line_instrumentation('#{filename}', #{line_no}); " + segment
            end
          else
            instrumented_line = segment
          end
        end

        instrumented_text << instrumented_line

        progress_dialog.set_overall_progress(line_no / num_lines) if progress_dialog and line_no
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
        Kernel.raise StopScript if @stop

        # Handle needing to change tabs
        handle_potential_tab_change(filename)

        # Adjust line number for offset in main script
        line_number = line_number + @line_offset if @active_script.object_id == @script.object_id
        detail_string = nil
        if filename
          detail_string = File.basename(filename) << ':' << line_number.to_s
        end
        Logger.detail_string = detail_string

        # Highlight the line that is about to run
        Qt.execute_in_main_thread(true) do
          @active_script.center_line(line_number)
          @active_script.highlight_line
        end

        # Handle pausing the script
        handle_pause(filename, line_number)

        # Handle delay between lines
        handle_line_delay()
      end
    end

    def post_line_instrumentation(filename, line_number)
      if @use_instrumentation
        line_number = line_number + @line_offset if @active_script.object_id == @script.object_id
        handle_output_io(filename, line_number)
      end
    end

    def exception_instrumentation(error, filename, line_number)
      if error.class == StopScript || error.class == SkipTestCase || !@use_instrumentation
        Kernel.raise error
      elsif !error.eql?(@@error)
        line_number = line_number + @line_offset if @active_script.object_id == @script.object_id
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

    # Prompts the user that a script is running before they close the app
    def prompt_if_running_on_close
      safe_to_continue = true
      if running?
        case Qt::MessageBox.warning(
          self,      # parent
          'Warning', # title
          'A Script is Running! Close Anyways?', # text
          Qt::MessageBox::Yes | Qt::MessageBox::No, # buttons
          Qt::MessageBox::No) # default button
        when Qt::MessageBox::Yes
          safe_to_continue = true
          ScriptRunnerFrame.stop!
        else
          safe_to_continue = false
        end
      end
      return safe_to_continue
    end

    ######################################
    # Implement the breakpoint callbacks from the RubyEditor
    ######################################
    def breakpoint_set(line)
      # Check for blank and comment lines which can't have a breakpoint.
      # There are other un-instrumentable lines which don't support breakpoints
      # but this is the most common and is an easy check.
      # Note: line is 1 based but @script.get_line is zero based so subtract 1
      text = @active_script.get_line(line - 1)
      if text && (text.strip.empty? || text.strip[0] == '#')
        @active_script.clear_breakpoint(line) # Immediately clear it
      else
        ScriptRunnerFrame.set_breakpoint(current_tab_filename(), line)
      end
    end

    def breakpoint_cleared(line)
      ScriptRunnerFrame.clear_breakpoint(current_tab_filename(), line)
    end

    def breakpoints_cleared
      ScriptRunnerFrame.clear_breakpoints(current_tab_filename())
    end

    ######################################
    # Implement edit functionality in the frame (cut, copy, paste, etc)
    ######################################
    def undo
      @script.undo unless running?()
    end

    def redo
      @script.redo unless running?()
    end

    def cut
      @script.cut unless running?()
    end

    def copy
      @script.copy unless running?()
    end

    def paste
      @script.paste unless running?()
    end

    def select_all
      @script.select_all unless running?()
    end

    def comment_or_uncomment_lines
      @script.comment_or_uncomment_lines unless running?()
    end

    def zoom_in
      # @active_script since this can be used while running
      @active_script.zoom_in
    end

    def zoom_out
      # @active_script since this can be used while running
      @active_script.zoom_out
    end

    def zoom_default
      # @active_script since this can be used while running
      @active_script.zoom_default
    end

    ##################################################################################
    # Implement Script functionality in the frame (run selection, run from cursor, etc
    ##################################################################################
    def run_selection
      unless self.class.running?()
        selection = @script.selected_lines
        if selection
          start_line_number = @script.selection_start_line
          end_line_number   = @script.selection_end_line
          scriptrunner_puts "Running script lines #{start_line_number+1}-#{end_line_number+1}: #{File.basename(@filename)}"
          handle_output_io()
          run_text(selection, start_line_number)
        end
      end
    end

    def run_selection_while_paused
      current_script = @tab_book.widget(@tab_book.currentIndex)
      selection = current_script.selected_lines
      if selection
        start_line_number = current_script.selection_start_line
        end_line_number   = current_script.selection_end_line
        scriptrunner_puts "Debug: Running selected lines #{start_line_number+1}-#{end_line_number+1}: #{@tab_book.tabText(@tab_book.currentIndex)}"
        handle_output_io()
        dialog = ScriptRunnerDialog.new(self, 'Executing Selected Lines While Paused')
        dialog.execute_text_and_close_on_complete(selection, @script_binding)
        handle_output_io()
      end
    end

    def run_from_cursor
      unless self.class.running?()
        line_number = @script.selection_start_line
        text = @script.toPlainText.split("\n")[line_number..-1].join("\n")
        scriptrunner_puts "Running script from line #{line_number}: #{File.basename(@filename)}"
        handle_output_io()
        run_text(text, line_number)
      end
    end

    def ruby_syntax_check_selection
      unless self.class.running?()
        selection = @script.selected_lines
        ruby_syntax_check_text(selection) if selection
      end
    end

    def ruby_syntax_check_text(selection = nil)
      unless self.class.running?()
        selection = text() unless selection
        check_process = IO.popen("ruby -c -rubygems 2>&1", 'r+')
        check_process.write("require 'cosmos'; require 'cosmos/script'; " + selection)
        check_process.close_write
        results = check_process.gets
        check_process.close
        if results
          if results =~ /Syntax OK/
            Qt::MessageBox.information(self, 'Syntax Check Successful', results)
          else
            # Results is a string like this: ":2: syntax error ..."
            # Normally the procedure comes before the first colon but since we
            # are writing to the process this is blank so we throw it away
            _, line_no, error = results.split(':')
            Qt::MessageBox.warning(self,
                                   'Syntax Check Failed',
                                   "Error on line #{line_no}: #{error.strip}")
          end
        else
          Qt::MessageBox.critical(self,
                                  'Syntax Check Exception',
                                  'Ruby syntax check unexpectedly returned nil')
        end
      end
    end

    def mnemonic_check_selection
      unless self.class.running?()
        selection = @script.selected_lines
        mnemonic_check_text(selection, @script.selection_start_line+1) if selection
      end
    end

    def mnemonic_check_text(text, start_line_number = 1)
      results = []
      line_number = start_line_number
      text.each_line do |line|
        if line =~ /\(/
          result = nil
          keyword = line.split('(')[0].split[-1]
          if CMD_KEYWORDS.include? keyword
            result = mnemonic_check_cmd_line(keyword, line_number, line)
          elsif TLM_KEYWORDS.include? keyword
            result = mnemonic_check_tlm_line(keyword, line_number, line)
          elsif SET_TLM_KEYWORDS.include? keyword
            result = mnemonic_check_set_tlm_line(keyword, line_number, line)
          elsif CHECK_KEYWORDS.include? keyword
            result = mnemonic_check_check_line(keyword, line_number, line)
          end
          results << result if result
        end
        line_number += 1
      end

      if results.empty?
        Qt::MessageBox.information(self,
                                   'Mnemonic Check Successful',
                                   'Mnemonic Check Found No Errors')
      else
        dialog = Qt::Dialog.new(self) do |box|
          box.setWindowTitle('Mnemonic Check Failed')
          text = Qt::PlainTextEdit.new
          text.setReadOnly(true)
          text.setPlainText(results.join("\n"))
          frame = Qt::VBoxLayout.new(box)
          ok = Qt::PushButton.new('Ok')
          ok.setDefault(true)
          ok.connect(SIGNAL('clicked(bool)')) { box.accept }
          frame.addWidget(text)
          frame.addWidget(ok)
        end
        dialog.exec
        dialog.dispose
      end
    end

    ######################################################
    # Implement the debug capability
    ######################################################
    def toggle_debug(debug = nil)
      if debug.nil?
        if @debug_frame
          hide_debug()
        else
          show_debug()
        end
      else
        if debug
          if !@debug_frame
            show_debug()
          end
        else
          if @debug_frame
            hide_debug()
          end
        end
      end
    end

    def show_debug
      unless @debug_frame
        @realtime_button_bar.step_button.setHidden(false)
        @script.enable_breakpoints = true
        if @tab_book_shown
          if @tab_book.count > 0
            (0..(@tab_book.count - 1)).each do |index|
              @tab_book.widget(index).enable_breakpoints = true
            end
          end
        end

        @debug_frame = Qt::HBoxLayout.new
        @debug_frame.setContentsMargins(0,0,0,0)
        @debug_frame_label = Qt::Label.new("Debug:")
        @debug_frame.addWidget(@debug_frame_label)
        @debug_text = CompletionLineEdit.new(self)
        @debug_text.setFocus(Qt::OtherFocusReason)
        @debug_text.connect(SIGNAL('key_pressed(QKeyEvent*)')) do |event|
          case event.key
          when Qt::Key_Return, Qt::Key_Enter
            begin
              debug_text = @debug_text.toPlainText
              @debug_history.unshift(debug_text)
              @debug_history_index = 0
              @debug_text.setPlainText('')
              scriptrunner_puts "Debug: #{debug_text}"
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
          when Qt::Key_Up
            if @debug_history.length > 0
              @debug_text.setPlainText(@debug_history[@debug_history_index])
              @debug_history_index += 1
              if @debug_history_index == @debug_history.length
                @debug_history_index = @debug_history.length-1
              end
            end
          when Qt::Key_Down
            if @debug_history.length > 0
              @debug_text.setPlainText(@debug_history[@debug_history_index])
              @debug_history_index -= 1
              @debug_history_index = 0 if @debug_history_index < 0
            end
          when Qt::Key_Escape
            @debug_text.setPlainText("")
          end
        end
        @debug_frame.addWidget(@debug_text)

        @locals_button = Qt::PushButton.new('Locals')
        @locals_button.connect(SIGNAL('clicked(bool)')) do
          next unless @script_binding
          @locals_button.setEnabled(false)
          vars = @script_binding.local_variables.map(&:to_s)
          puts "Locals: #{vars.reject {|x| INSTANCE_VARS.include?(x)}.sort.join(', ')}"
          while @output_io.string[-1..-1] == "\n"
            Qt::CoreApplication.processEvents()
          end
          @locals_button.setEnabled(true)
        end
        @debug_frame.addWidget(@locals_button)

        @bottom_frame.layout.addLayout(@debug_frame)
      end
    end

    def hide_debug
      # Since we're disabling debug, clear the breakpoints and disable them
      ScriptRunnerFrame.clear_breakpoints()
      @script.clear_breakpoints
      @script.enable_breakpoints = false
      if @tab_book_shown
        if @tab_book.count > 0
          (0..(@tab_book.count - 1)).each do |index|
            @tab_book.widget(index).enable_breakpoints = false
          end
        end
      end
      @realtime_button_bar.step_button.setHidden(true)
      # Remove the debug frame
      @bottom_frame.layout.takeAt(@bottom_frame.layout.count - 1) if @debug_frame
      @debug_frame.removeAll
      @debug_frame.dispose
      @debug_frame = nil

      # If step mode was previously active then pause the script so it doesn't
      # just take off when we end the debugging session
      if @@step_mode
        pause()
        @@step_mode = false
      end
    end

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

    def select_tab_and_destroy_tabs_after_index(index)
      Qt.execute_in_main_thread(true) do
        if @tab_book_shown
          @tab_book.setCurrentIndex(index)
          @active_script = @tab_book.widget(@tab_book.currentIndex)

          first_to_remove = index + 1
          last_to_remove  = @call_stack.length - 1

          last_to_remove.downto(first_to_remove) do |tab_index|
            tab = @tab_book.widget(tab_index)
            @tab_book.removeTab(tab_index)
            tab.dispose
          end

          @call_stack = @call_stack[0..index]
          @current_file = @call_stack[index]
        end
      end
    end

    def toggle_disconnect(config_file, ask_for_config_file = true)
      dialog = Qt::Dialog.new(self, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
      dialog.setWindowTitle("Disconnect Settings")
      dialog_layout = Qt::VBoxLayout.new
      dialog_layout.addWidget(Qt::Label.new("Targets checked will be disconnected."))

      all_targets = {}
      set_clear_layout = Qt::HBoxLayout.new
      check_all = Qt::PushButton.new("Check All")
      check_all.setAutoDefault(false)
      check_all.setDefault(false)
      check_all.connect(SIGNAL('clicked()')) do
        all_targets.each do |target, checkbox|
          checkbox.setChecked(true)
        end
      end
      set_clear_layout.addWidget(check_all)
      clear_all = Qt::PushButton.new("Clear All")
      clear_all.connect(SIGNAL('clicked()')) do
        all_targets.each do |target, checkbox|
          checkbox.setChecked(false)
        end
      end
      set_clear_layout.addWidget(clear_all)
      dialog_layout.addLayout(set_clear_layout)

      scroll = Qt::ScrollArea.new
      target_widget = Qt::Widget.new
      scroll.setWidget(target_widget)
      target_layout = Qt::VBoxLayout.new(target_widget)
      target_layout.setSizeConstraint(Qt::Layout::SetMinAndMaxSize)
      scroll.setSizePolicy(Qt::SizePolicy::Preferred, Qt::SizePolicy::Expanding)
      scroll.setWidgetResizable(true)

      existing = get_disconnected_targets()
      System.targets.keys.each do |target|
        check_layout = Qt::HBoxLayout.new
        check_label = Qt::CheckboxLabel.new(target)
        checkbox = Qt::CheckBox.new
        all_targets[target] = checkbox
        if existing
          checkbox.setChecked(existing && existing.include?(target))
        else
          checkbox.setChecked(true)
        end
        check_label.setCheckbox(checkbox)
        check_layout.addWidget(checkbox)
        check_layout.addWidget(check_label)
        check_layout.addStretch
        target_layout.addLayout(check_layout)
      end
      dialog_layout.addWidget(scroll)

      if ask_for_config_file
        chooser = FileChooser.new(self, "Config File", config_file, 'Select',
                                  File.dirname(config_file))
        chooser.callback = lambda do |filename|
          chooser.filename = filename
        end
        dialog_layout.addWidget(chooser)
      end

      button_layout = Qt::HBoxLayout.new
      ok = Qt::PushButton.new("Ok")
      ok.setAutoDefault(true)
      ok.setDefault(true)
      targets = []
      ok.connect(SIGNAL('clicked()')) do
        all_targets.each do |target, checkbox|
          targets << target if checkbox.isChecked
        end
        dialog.accept()
      end
      button_layout.addWidget(ok)
      cancel = Qt::PushButton.new("Cancel")
      cancel.connect(SIGNAL('clicked()')) do
        dialog.reject()
      end
      button_layout.addWidget(cancel)
      dialog_layout.addLayout(button_layout)

      dialog.setLayout(dialog_layout)
      my_parent = self.parent
      while my_parent.parent
        my_parent = my_parent.parent
      end
      if dialog.exec == Qt::Dialog::Accepted
        if targets.empty?
          clear_disconnected_targets()
          my_parent.statusBar.showMessage("")
          self.setPalette(Qt::Palette.new(Cosmos::DEFAULT_PALETTE))
        else
          config_file = chooser.filename
          my_parent.statusBar.showMessage("Targets disconnected: #{targets.join(" ")}")
          self.setPalette(Qt::Palette.new(Cosmos::RED_PALETTE))
          Splash.execute(self) do |splash|
            ConfigParser.splash = splash
            splash.message = "Initializing Command and Telemetry Server"
            set_disconnected_targets(targets, targets.length == all_targets.length, config_file)
            ConfigParser.splash = nil
          end
        end
      end
      dialog.dispose
      config_file
    end

    def current_backtrace
      trace = []
      Qt.execute_in_main_thread(true) do
        if @@run_thread
          temp_trace = @@run_thread.backtrace
          cosmos_lib = Regexp.new(File.join(Cosmos::PATH, 'lib'))
          temp_trace.each do |line|
            next if line =~ cosmos_lib
            trace << line
          end
        end
      end
      trace
    end

    def scriptrunner_puts(string)
      puts Time.now.sys.formatted + " (SCRIPTRUNNER): "  + string
    end

    def handle_output_io(filename = @current_filename, line_number = @current_line_number)
      @output_time = Time.now.sys
      Qt.execute_in_main_thread(true) do
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
            color = nil
            if out_line[0..1] == '20' and out_line[10] == ' ' and out_line[23..24] == ' ('
              line_to_write = out_line
            else
              if filename
                line_to_write = time_formatted + " (#{out_filename}:#{out_line_number}): "  + out_line
              else
                line_to_write = time_formatted + " (SCRIPTRUNNER): "  + out_line
                color = Cosmos::BLUE
              end
            end
            @output.add_formatted_text(line_to_write, color)
            lines_to_write << line_to_write

            line_count += 1
            if line_count > @stdout_max_lines
              out_line = "ERROR: Too much written to stdout.  Truncating output to #{@stdout_max_lines} lines.\n"
              if filename
                line_to_write = time_formatted + " (#{out_filename}:#{out_line_number}): "  + out_line
              else
                line_to_write = time_formatted + " (SCRIPTRUNNER): "  + out_line
              end
              @output.addText(line_to_write, Cosmos::RED)
              lines_to_write << line_to_write
              break
            end
          end # string.each_line

          # Actually add to the GUI
          @output.flush

          # Add to the message log
          if @filename.empty?
            @message_log ||= MessageLog.new("sr_untitled")
          else
            @message_log ||= MessageLog.new("sr_#{File.basename(@filename).split('.')[0]}")
          end
          @message_log.write(lines_to_write)
        end
      end
    end

    def graceful_kill
      # Just to avoid warning
    end

    protected

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
      @active_script = @script
      @call_stack = []
      @pre_line_time = Time.now.sys
      @current_file = @filename
      @exceptions = nil
      @script_binding = nil
      @inline_eval = nil
      @current_filename = nil
      @current_line_number = 0
      @stdout_max_lines = 1000

      @script.stop_highlight
      @call_stack.push(@current_file.dup)
    end

    def wait_for_go_or_stop(error = nil)
      @go = false
      sleep(0.01) until @go or @stop
      @go = false
      mark_running()
      Kernel.raise StopScript if @stop
      Kernel.raise error if error and !@continue_after_error
    end

    def wait_for_go_or_stop_or_retry(error = nil)
      @go = false
      sleep(0.01) until @go or @stop or @retry_needed
      @go = false
      mark_running()
      Kernel.raise StopScript if @stop
      Kernel.raise error if error and !@continue_after_error
    end

    def mark_running
      Qt.execute_in_main_thread(true) do
        @run_callback.call(self) if @run_callback
        @active_script.highlight_line
        @realtime_button_bar.state = 'Running'
        @realtime_button_bar.start_button.setText('Go')
        @realtime_button_bar.pause_button.setText('Pause')
      end
    end

    def mark_paused
      Qt.execute_in_main_thread(true) do
        @pause_callback.call(self) if @pause_callback
        @active_script.highlight_line('lightblue')
        @realtime_button_bar.state = 'Paused'
      end
    end

    def mark_error
      Qt.execute_in_main_thread(true) do
        @error_callback.call(self) if @error_callback
        @active_script.highlight_line('pink')
        @realtime_button_bar.state = 'Error'
        @realtime_button_bar.pause_button.setText('Retry')
      end
    end

    def mark_stopped
      stop_message_log()
      Qt.execute_in_main_thread(true) do
        @realtime_button_bar.start_button.setText('Start')
        @realtime_button_bar.pause_button.setText('Pause')
        @realtime_button_bar.state = 'Stopped'
        @stop_callback.call(self) if @stop_callback
      end
    end

    def mark_breakpoint
      Qt.execute_in_main_thread(true) do
        @active_script.highlight_line('tan')
        @realtime_button_bar.state = 'Breakpoint'
      end
    end

    def run_text(text,
                 line_offset = 0,
                 text_binding = nil,
                 close_on_complete = false)
      @run_callback.call(self) if @run_callback
      @realtime_button_bar.start_button.setEnabled(true)
      initialize_variables()
      create_tabs()
      @line_offset = line_offset
      @script.setReadOnly(true)
      @realtime_button_bar.start_button.setText(' Go ')
      @realtime_button_bar.state = 'Running'

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
            targets = get_disconnected_targets()
            if targets
              scriptrunner_puts("DISCONNECTED targets: #{targets.join(',')}")
            end
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
          if error.class == StopScript or error.class == SkipTestCase
            scriptrunner_puts "Script stopped: #{File.basename(@filename)}"
            handle_output_io()
          else
            uncaught_exception = true
            filename, line_number = error.source
            handle_exception(error, true, filename, line_number)
            scriptrunner_puts "Exception in Control Statement - Script stopped: #{File.basename(@filename)}"
            handle_output_io()
            Qt.execute_in_main_thread(true) { @script.highlight_line('red') }
          end
        ensure
          # Change Go Button to Start Button and remove highlight
          Qt.execute_in_main_thread(true) do
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
              Qt::CoreApplication.processEvents()
              Cosmos.kill_thread(self, @@limits_monitor_thread)
              @@limits_monitor_thread = nil
            end
            if @@output_thread and not @@instance
              @@cancel_output = true
              @@output_sleeper.cancel
              Qt::CoreApplication.processEvents()
              Cosmos.kill_thread(self, @@output_thread)
              @@output_thread = nil
            end

            @script.setReadOnly(false)
            @script.stop_highlight unless uncaught_exception
            select_tab_and_destroy_tabs_after_index(0)
            remove_tabs()
            unless @allow_start
              @realtime_button_bar.start_button.setEnabled(false)
              @script.setReadOnly(true)
            end
            mark_stopped()
            if close_on_complete
              self.parent.done(0)
            end
          end
        end
      end
    end

    def handle_potential_tab_change(filename)
      # Make sure the correct file is shown in script runner
      if @current_file != filename and @tab_book_shown
        Qt.execute_in_main_thread(true) do
          if @call_stack.include?(filename)
            index = @call_stack.index(filename)
            select_tab_and_destroy_tabs_after_index(index)
          else # new file
            # Create new tab
            new_script = create_ruby_editor()
            new_script.filename = filename
            @tab_book.addTab(new_script, '  ' + File.basename(filename) + '  ')

            @call_stack.push(filename.dup)

            # Switch to new tab
            @tab_book.setCurrentIndex(@tab_book.count - 1)
            @active_script = new_script
            load_file_into_script(filename)
            new_script.setReadOnly(true)
          end

          @current_file = filename
        end
      end
    end

    def show_active_tab
      @tab_book.setCurrentIndex(@call_stack.length - 1) if @tab_book_shown
    end

    def handle_pause(filename, line_number)
      bkpt_filename = ''
      Qt.execute_in_main_thread(true) {bkpt_filename = @active_script.filename}
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
        if Qt::MessageBox.warning(self, "Warning", "If an error occurs, the script will not pause and will run to completion. Continue?", Qt::MessageBox::Yes | Qt::MessageBox::No, Qt::MessageBox::Yes) == Qt::MessageBox::No
          return false
        end
      end
      true
    end

    def handle_step_button
      scriptrunner_puts "User pressed #{@realtime_button_bar.step_button.text.strip}"
      pause()
      @@step_mode = true
      handle_start_go_button(step = true)
    end

    def handle_start_go_button(step = false)
      unless step
        scriptrunner_puts "User pressed #{@realtime_button_bar.start_button.text.strip}"
        @@step_mode = false
      end
      handle_output_io()
      @realtime_button_bar.start_button.clear_focus()

      if running?()
        show_active_tab()
        go()
      else
        if @allow_start
          run() if continue_without_pausing_on_errors?()
        end
      end
    end

    def handle_pause_retry_button
      scriptrunner_puts "User pressed #{@realtime_button_bar.pause_button.text.strip}"
      handle_output_io()
      @realtime_button_bar.pause_button.clear_focus()
      show_active_tab() if running?
      if @realtime_button_bar.pause_button.text.to_s == 'Pause'
        pause()
      else
        retry_needed()
      end
    end

    def handle_stop_button
      scriptrunner_puts "User pressed #{@realtime_button_bar.stop_button.text.strip}"
      handle_output_io()
      @realtime_button_bar.stop_button.clear_focus()

      if @stop
        # If we're already stopped and they click Stop again, kill the run
        # thread. This will break any ruby sleeps or other code blocks.
        ScriptRunnerFrame.stop!
        handle_output_io()
      else
        @stop = true
      end
      if !running?()
        # Stop highlight if there was a red syntax error
        @script.stop_highlight
      end
    end

    def handle_exception(error, fatal, filename = nil, line_number = 0)
      @error_callback.call(self) if @error_callback

      @exceptions ||= []
      @exceptions << error
      @@error = error

      if error.class == DRb::DRbConnError
        Logger.error("Error Connecting to Command and Telemetry Server")
      elsif error.class == CheckError
        Logger.error(error.message)
      else
        Logger.error(error.class.to_s.split('::')[-1] + ' : ' + error.message)
      end
      Logger.error(error.backtrace.join("\n")) if @@show_backtrace
      handle_output_io(filename, line_number)

      Kernel.raise error if !@@pause_on_error and !@continue_after_error and !fatal

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

    # Right click context_menu for the script
    def context_menu(point)
      # Only show context menu if not running or paused.  Otherwise will segfault if current tab goes away while menu
      # is shown
      if not self.class.running? or (running?() and @realtime_button_bar.state != 'Running')
        if @tab_book_shown
          current_script = @tab_book.widget(@tab_book.currentIndex)
        else
          current_script = @script
        end
        menu = current_script.context_menu(point)
        menu.addSeparator()
        if not self.class.running?
          exec_selected_action = Qt::Action.new("Execute Selected Lines", self)
          exec_selected_action.statusTip = "Execute the selected lines as a standalone script"
          exec_selected_action.connect(SIGNAL('triggered()')) { run_selection() }
          menu.addAction(exec_selected_action)

          exec_cursor_action = Qt::Action.new("Execute From Cursor", self)
          exec_cursor_action.statusTip = "Execute the script starting at the line containing the cursor"
          exec_cursor_action.connect(SIGNAL('triggered()')) { run_from_cursor() }
          menu.addAction(exec_cursor_action)

          menu.addSeparator()

          if RUBY_VERSION.split('.')[0].to_i > 1
            syntax_action = Qt::Action.new("Ruby Syntax Check Selected Lines", self)
            syntax_action.statusTip = "Check the selected lines for valid Ruby syntax"
            syntax_action.connect(SIGNAL('triggered()')) { ruby_syntax_check_selection() }
            menu.addAction(syntax_action)
          end

          mnemonic_action = Qt::Action.new("Mnemonic Check Selected Lines", self)
          mnemonic_action.statusTip = "Check the selected lines for valid targets, packets, mnemonics and parameters"
          mnemonic_action.connect(SIGNAL('triggered()')) { mnemonic_check_selection() }
          menu.addAction(mnemonic_action)

        elsif running?() and @realtime_button_bar.state != 'Running'
          exec_selected_action = Qt::Action.new("Execute Selected Lines While Paused", self)
          exec_selected_action.statusTip = "Execute the selected lines as a standalone script"
          exec_selected_action.connect(SIGNAL('triggered()')) { run_selection_while_paused() }
          menu.addAction(exec_selected_action)
        end
        menu.exec(current_script.mapToGlobal(point))
        menu.dispose
      end
    end

    def load_file_into_script(filename)
      cached = @@file_cache[filename]
      if cached
        @active_script.setPlainText(cached.gsub("\r", ''))
      else
        if File.exist?(filename)
          data = File.read(filename).gsub("\r", '')
        else
          data = ""
        end
        @active_script.setPlainText(data)
      end
      mark_breakpoints(filename)

      @active_script.stop_highlight
    end

    def mark_breakpoints(filename)
      breakpoints = @@breakpoints[filename]
      if breakpoints
        breakpoints.each do |line_number, present|
          @active_script.add_breakpoint(line_number) if present
        end
      end
    end

    def redirect_io
      # Redirect Standard Output and Standard Error
      $stdout = Stdout.instance
      $stderr = Stderr.instance

      # Disable outputting to default io file descriptors
      $stdout.remove_default_io
      $stderr.remove_default_io

      Logger.level = Logger::INFO
      Logger::INFO_SEVERITY_STRING.replace('')
      Logger::WARN_SEVERITY_STRING.replace('<Y> WARN:')
      Logger::ERROR_SEVERITY_STRING.replace('<R> ERROR:')
    end

    def create_tabs
      tab_text = @default_tab_text
      tab_text = '  ' + File.basename(@filename) + '  ' unless @filename.empty?
      @tab_book.addTab(@script, tab_text)
      @top_frame.insertWidget(0, @tab_book)
      @tab_book_shown = true
    end

    def remove_tabs
      @top_frame.takeAt(0) # Remove the @tab_book from the layout
      @top_frame.addWidget(@script) # Add back the script
      @script.show
      @tab_book_shown = false
    end

    def isolate_string(keyword, line)
      found_string = nil

      # Find keyword
      keyword_index = line.index(keyword)

      # Remove keyword from line
      line = line[(keyword_index + keyword.length)..-1]

      # Find start parens
      start_parens = line.index('(')
      if start_parens
        end_parens   = line[start_parens..-1].index(')')
        found_string = line[(start_parens + 1)..(end_parens + start_parens - 1)].remove_quotes if end_parens
        if keyword == 'wait' or keyword == 'wait_check'
          quote_index = found_string.rindex('"')
          quote_index = found_string.rindex("'") unless quote_index
          if quote_index
            found_string = found_string[0..quote_index].remove_quotes
          else
            found_string = nil
          end
        end
      end
      found_string
    end

    def mnemonic_check_cmd_line(keyword, line_number, line)
      result = nil

      # Isolate the string
      string = isolate_string(keyword, line)
      if string
        begin
          target_name, cmd_name, cmd_params = extract_fields_from_cmd_text(string)
          result = "At line #{line_number}: Unknown command: #{target_name} #{cmd_name}"
          packet = System.commands.packet(target_name, cmd_name)
          Kernel.raise "Command not found" unless packet
          cmd_params.each do |param_name, param_value|
            result = "At line #{line_number}: Unknown command parameter: #{target_name} #{cmd_name} #{param_name}"
            packet.get_item(param_name)
          end
          result = nil
        rescue
          if result
            if string.index('=>')
              # Assume alternative syntax
              result = nil
            end
          else
            result = "At line #{line_number}: Potentially malformed command: #{line}"
          end
        end
      end

      result
    end

    def _mnemonic_check_tlm_line(keyword, line_number, line)
      result = nil

      # Isolate the string
      string = isolate_string(keyword, line)
      if string
        begin
          target_name, packet_name, item_name = yield string
          result = "At line #{line_number}: Unknown telemetry item: #{target_name} #{packet_name} #{item_name}"
          System.telemetry.packet_and_item(target_name, packet_name, item_name)
          result = nil
        rescue
          if result
            if string.index(',')
              # Assume alternative syntax
              result = nil
            end
          else
            result = "At line #{line_number}: Potentially malformed telemetry: #{line}"
          end
        end
      end

      result
    end

    def mnemonic_check_tlm_line(keyword, line_number, line)
      _mnemonic_check_tlm_line(keyword, line_number, line) do |string|
        extract_fields_from_tlm_text(string)
      end
    end

    def mnemonic_check_set_tlm_line(keyword, line_number, line)
      _mnemonic_check_tlm_line(keyword, line_number, line) do |string|
        extract_fields_from_set_tlm_text(string)
      end
    end

    def mnemonic_check_check_line(keyword, line_number, line)
      _mnemonic_check_tlm_line(keyword, line_number, line) do |string|
        extract_fields_from_check_text(string)
      end
    end

    def output_thread
      @@cancel_output = false
      @@output_sleeper = Sleeper.new
      begin
        loop do
          break if @@cancel_output
          handle_output_io() if (Time.now.sys - @output_time) > 5.0
          break if @@cancel_output
          break if @@output_sleeper.sleep(1.0)
        end # loop
      rescue => error
        Qt.execute_in_main_thread(true) do
          ExceptionDialog.new(self, error, "Output Thread")
        end
      end
    end

    def limits_monitor_thread
      @@cancel_limits = false
      @@limits_sleeper = Sleeper.new
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
                    scriptrunner_puts "<Y>#{msg}"
                  when :RED, :RED_LOW, :RED_HIGH
                    scriptrunner_puts "<R>#{msg}"
                  else
                    # Print nothing
                  end
                  handle_output_io()
                end
              else # changing from a color
                msg = "#{target_name} #{packet_name} #{item_name} is #{new_limits_state.to_s}"
                case new_limits_state
                when :BLUE
                  scriptrunner_puts "<B>#{msg}"
                when :GREEN, :GREEN_LOW, :GREEN_HIGH
                  scriptrunner_puts "<G>#{msg}"
                when :YELLOW, :YELLOW_LOW, :YELLOW_HIGH
                  scriptrunner_puts "<Y>#{msg}"
                when :RED, :RED_LOW, :RED_HIGH
                  scriptrunner_puts "<R>#{msg}"
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
        Qt.execute_in_main_thread(true) do
          ExceptionDialog.new(self, error, "Limits Monitor Thread")
        end
      end
    ensure
      begin
        unsubscribe_limits_events(queue_id) if queue_id
      rescue
        # Oh Well
      end
    end
  end
end
