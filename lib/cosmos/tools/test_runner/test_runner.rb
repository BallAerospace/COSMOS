# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
Cosmos.catch_fatal_exception do
  require 'ostruct'
  require 'cosmos/gui/qt_tool'
  require 'cosmos/tools/test_runner/test'
  require 'cosmos/tools/test_runner/results_writer'
  require 'cosmos/tools/test_runner/test_runner_chooser'
  require 'cosmos/tools/script_runner/script_runner_frame'
  require 'cosmos/tools/script_runner/script_audit'
  require 'cosmos/gui/dialogs/progress_dialog'
  require 'cosmos/gui/dialogs/scroll_text_dialog'
  require 'yard'
end

module Cosmos

  # Placeholder for all tests discovered without assigned TestSuites
  class UnassignedTestSuite < TestSuite
  end

  # TestRunner provides a framework for running repeatable sets of tests.
  # Individual Test Cases are grouped into Test Groups which are collected into
  # Test Suites. Test Cases can have manual sections and can be looped
  # indefinitely. After all the tests have run a test report is generated which
  # lists the pass / fail status of each test case.
  class TestRunner < QtTool
    slots 'status_timeout()'

    @@test_suites = []
    @@suites = {}
    @@results_writer = ResultsWriter.new
    @@settings = {}
    @@started_success = false
    @@instance = nil

    UNASSIGNED_SUITE_DESCRIPTION = "This Test Suite is created automatically " \
      "by Test Runner to hold all Tests that have not been added to Test " \
      "Suites. Consider adding these tests to explicit Test Suites to " \
      "eliminate this catch all Test Suite."

    def initialize(options)
      # All code before super is executed twice in RubyQt Based classes
      super(options) # MUST BE FIRST
      Cosmos.load_cosmos_icon("test_runner.png")

      # Add procedures to search path
      System.paths['PROCEDURES'].each do |path|
        Cosmos.add_to_search_path(path)
      end

      initialize_actions()
      initialize_menus()
      initialize_central_widget()
      complete_initialize()

      # Instance variables
      @utilities = []
      @procedure_dirs = System.paths['PROCEDURES']
      @server_config_file = options.server_config_file
      @ignore_tests = []
      @ignore_test_suites = []
      Splash.execute(self) do |splash|
        ConfigParser.splash = splash
        process_config(options.config_file)
        if options.test_suite
          Qt.execute_in_main_thread do
            # Start the test and don't warn the user about their options
            handle_start(options.test_suite, options.test_group, options.test_case, false)
          end
        end
        ConfigParser.splash = nil
      end

      # Timeout to update executing test case status
      @timer = Qt::Timer.new(self)
      connect(@timer, SIGNAL('timeout()'), self, SLOT('status_timeout()'))
      @timer.method_missing(:start, 100)

      @@instance = self
    end

    def initialize_actions
      super()

      # File Actions
      @show_last = Qt::Action.new('Show &Results', self)
      @show_last_keyseq = Qt::KeySequence.new('Ctrl+R')
      @show_last.shortcut = @show_last_keyseq
      @show_last.statusTip = 'Show the Results dialog from the last run'
      @show_last.connect(SIGNAL('triggered()')) { show_results }

      @select = Qt::Action.new('Test &Selection', self)
      @select_keyseq = Qt::KeySequence.new('Ctrl+S')
      @select.shortcut = @select_keyseq
      @select.statusTip = 'Select Test Suites/Groups/Cases'
      @select.connect(SIGNAL('triggered()')) { show_select }

      @file_options = Qt::Action.new('O&ptions', self)
      @file_options.statusTip = 'Application Options'
      @file_options.connect(SIGNAL('triggered()')) { file_options() }

      # Edit Actions
      @edit_zoom_in = Qt::Action.new('&Increase Font Size', self)
      @edit_zoom_in_keyseq = Qt::KeySequence.new(Qt::KeySequence::ZoomIn)
      @edit_zoom_in.shortcut  = @edit_zoom_in_keyseq
      @edit_zoom_in.connect(SIGNAL('triggered()')) { @script_runner_frame.zoom_in }
        @edit_zoom_out = Qt::Action.new('&Decrease Font Size', self)
      @edit_zoom_out_keyseq = Qt::KeySequence.new(Qt::KeySequence::ZoomOut)
      @edit_zoom_out.shortcut  = @edit_zoom_out_keyseq
      @edit_zoom_out.connect(SIGNAL('triggered()')) { @script_runner_frame.zoom_out }
        @edit_zoom_default = Qt::Action.new('Restore &Font Size', self)
      @edit_zoom_default.connect(SIGNAL('triggered()')) { @script_runner_frame.zoom_default }

      # Script Actions
      @test_results_log_message = Qt::Action.new('Log Message to Test Results', self)
      @test_results_log_message.statusTip = 'Log Message to Test Results'
      @test_results_log_message.connect(SIGNAL('triggered()')) { on_test_results_log_message() }
      @test_results_log_message.setEnabled(false)

      @script_log_message = Qt::Action.new('Log Message to Script Log', self)
      @script_log_message.statusTip = 'Log Message to Script Log'
      @script_log_message.connect(SIGNAL('triggered()')) { on_script_log_message() }
      @script_log_message.setEnabled(false)

      @show_call_stack = Qt::Action.new('Show Call Stack', self)
      @show_call_stack.statusTip = 'Show Call Stack'
      @show_call_stack.connect(SIGNAL('triggered()')) { on_script_call_stack }
      @show_call_stack.setEnabled(false)

      @toggle_debug = Qt::Action.new(Cosmos.get_icon('bug.png'), '&Toggle Debug', self)
      @toggle_debug_keyseq = Qt::KeySequence.new('Ctrl+D')
      @toggle_debug.shortcut  = @toggle_debug_keyseq
      @toggle_debug.statusTip = 'Toggle Debug'
      @toggle_debug.connect(SIGNAL('triggered()')) { on_script_toggle_debug }
      @toggle_debug.setEnabled(false)

      @script_disconnect = Qt::Action.new(Cosmos.get_icon('disconnected.png'), '&Toggle Disconnect', self)
      @script_disconnect_keyseq = Qt::KeySequence.new('Ctrl+T')
      @script_disconnect.shortcut  = @script_disconnect_keyseq
      @script_disconnect.statusTip = 'Toggle disconnect from the server'
      @script_disconnect.connect(SIGNAL('triggered()')) { on_script_toggle_disconnect() }

      @script_audit = Qt::Action.new('&Generate Cmd/Tlm Audit', self)
      @script_audit.statusTip = 'Generate audit about commands sent and telemetry checked'
      @script_audit.connect(SIGNAL('triggered()')) { script_audit() }
    end

    def initialize_menus
      # File Menu
      file_menu = menuBar.addMenu('&File')
      file_menu.addAction(@show_last)
      file_menu.addAction(@select)
      file_menu.addSeparator()
      file_menu.addAction(@file_options)
      file_menu.addSeparator()
      file_menu.addAction(@exit_action)

      # Edit Menu (to match Script Runner)
      edit_menu = menuBar.addMenu('&Edit')
      edit_menu.addAction(@edit_zoom_in)
      edit_menu.addAction(@edit_zoom_out)
      edit_menu.addAction(@edit_zoom_default)

      # Script Menu
      script_menu = menuBar.addMenu('&Script')
      script_menu.addAction(@test_results_log_message)
      script_menu.addAction(@script_log_message)
      script_menu.addAction(@show_call_stack)
      script_menu.addAction(@toggle_debug)
      script_menu.addAction(@script_disconnect)
      script_menu.addSeparator()
      script_menu.addAction(@script_audit)

      # Help Menu
      @about_string  = "Test Runner provides a framework for developing high " \
        "level tests that interact with a system using commands and telemetry."

      initialize_help_menu()
    end

    def initialize_central_widget
      # Create the top level vertical layout
      @central_widget = Qt::Widget.new()
      @frame = Qt::VBoxLayout.new(@central_widget)

      @horizontal_frame = Qt::HBoxLayout.new
      @horizontal_frame.setContentsMargins(0,0,0,0)
      @frame.addLayout(@horizontal_frame)

      # Check boxes
      @pause_on_error = Qt::CheckBox.new('Pause on Error')
      @pause_on_error.setChecked(true)
      @pause_on_error.setObjectName('PauseOnError')
      @continue_test_case_after_error = Qt::CheckBox.new('Continue Test Case after Error')
      @continue_test_case_after_error.setChecked(true)
      @continue_test_case_after_error.setObjectName('ContinueTestCaseAfterError')
      @abort_testing_after_error = Qt::CheckBox.new('Abort Testing after Error')
      @abort_testing_after_error.setChecked(false)
      @abort_testing_after_error.setObjectName('AbortTestingAfterError')

      @checkbox_frame = Qt::VBoxLayout.new
      @checkbox_frame.setContentsMargins(0,0,0,0)
      @checkbox_frame.addWidget(@pause_on_error)
      @checkbox_frame.addWidget(@continue_test_case_after_error)
      @checkbox_frame.addWidget(@abort_testing_after_error)
      @horizontal_frame.addLayout(@checkbox_frame)

      # Separator Between checkboxes
      @sep1 = Qt::Frame.new(@central_widget)
      @sep1.setFrameStyle(Qt::Frame::VLine | Qt::Frame::Sunken)
      @horizontal_frame.addWidget(@sep1)

      @manual = Qt::CheckBox.new('Manual')
      @manual.setChecked(true)
      @manual.setObjectName('Manual')
      @manual.connect(SIGNAL('stateChanged(int)')) do
        if @manual.isChecked()
          $manual = true
        else
          $manual = false
        end
        0
      end
      $manual = true
      @loop_testing = Qt::CheckBox.new('Loop Testing')
      @loop_testing.setChecked(false)
      @loop_testing.setObjectName('LoopTesting')
      @loop_testing.connect(SIGNAL('stateChanged(int)')) do
        if @loop_testing.isChecked()
          $loop_testing = true
          @break_loop_after_error.setEnabled(true)
        else
          $loop_testing = false
          @break_loop_after_error.setEnabled(false)
        end
        0
      end
      $loop_testing = false
      @break_loop_after_error = Qt::CheckBox.new('Break Loop after Error')
      @break_loop_after_error.setChecked(false)
      @break_loop_after_error.setEnabled(false)
      @break_loop_after_error.setObjectName('BreakLoopAfterError')

      @checkbox_frame = Qt::VBoxLayout.new
      @checkbox_frame.setContentsMargins(0,0,0,0)
      @checkbox_frame.addWidget(@manual)
      @checkbox_frame.addWidget(@loop_testing)
      @checkbox_frame.addWidget(@break_loop_after_error)
      @horizontal_frame.addLayout(@checkbox_frame)

      # Separator Between checkboxes
      @sep2 = Qt::Frame.new(@central_widget)
      @sep2.setFrameStyle(Qt::Frame::VLine | Qt::Frame::Sunken)
      @horizontal_frame.addStretch
      @horizontal_frame.addWidget(@sep2)

      # Create comboboxes and Start buttons
      @test_runner_chooser = TestRunnerChooser.new(self)
      @test_runner_chooser.setContentsMargins(0,0,0,0)
      @test_runner_chooser.test_suite_start_callback = method(:handle_start)
      @test_runner_chooser.test_start_callback = method(:handle_start)
      @test_runner_chooser.test_case_start_callback = method(:handle_start)
      @test_runner_chooser.test_suite_setup_callback = method(:handle_setup)
      @test_runner_chooser.test_setup_callback = method(:handle_setup)
      @test_runner_chooser.test_suite_teardown_callback = method(:handle_teardown)
      @test_runner_chooser.test_teardown_callback = method(:handle_teardown)
      @horizontal_frame.addWidget(@test_runner_chooser)

      # Executing Test Case Status
      @executing_status = Qt::HBoxLayout.new
      @executing_test_case_label = Qt::Label.new('Executing Test Case:')
      @executing_status.addWidget(@executing_test_case_label)
      @test_status = Qt::LineEdit.new
      @test_status.setReadOnly(true)
      @executing_status.addWidget(@test_status)
      @pass_label = Qt::Label.new('Pass:')
      @executing_status.addWidget(@pass_label)
      @pass_count  = Qt::LineEdit.new
      @pass_count.setFixedWidth(40)
      @pass_count.setReadOnly(true)
      @pass_count.setAlignment(Qt::AlignHCenter)
      @pass_count.setColors(Cosmos::GREEN, Cosmos::WHITE)
      @executing_status.addWidget(@pass_count)
      @skip_label = Qt::Label.new('Skip:')
      @executing_status.addWidget(@skip_label)
      @skip_count  = Qt::LineEdit.new
      @skip_count.setFixedWidth(40)
      @skip_count.setReadOnly(true)
      @skip_count.setAlignment(Qt::AlignHCenter)
      @skip_count.setColors(Cosmos::YELLOW, Cosmos::WHITE)
      @executing_status.addWidget(@skip_count)
      @fail_label = Qt::Label.new('Fail:')
      @executing_status.addWidget(@fail_label)
      @fail_count  = Qt::LineEdit.new
      @fail_count.setFixedWidth(40)
      @fail_count.setReadOnly(true)
      @fail_count.setAlignment(Qt::AlignHCenter)
      @fail_count.setColors(Cosmos::RED, Cosmos::WHITE)
      @executing_status.addWidget(@fail_count)
      @progress_bar = Qt::ProgressBar.new
      @progress_bar.setFixedWidth(200)
      @progress_bar.setMinimum(0)
      @progress_bar.setMaximum(100)
      @executing_status.addWidget(@progress_bar)
      @frame.addLayout(@executing_status)

      # Separator before ScriptRunnerFrame
      @sep3 = Qt::Frame.new(@central_widget)
      @sep3.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
      @frame.addWidget(@sep3)

      @script_runner_frame = ScriptRunnerFrame.new(self)
      @script_runner_frame.setContentsMargins(0,0,0,0)
      @script_runner_frame.stop_callback = method(:handle_stop)
      @script_runner_frame.allow_start = false
      ScriptRunnerFrame.pause_on_error = true
      @script_runner_frame.continue_after_error = true
      @script_runner_frame.error_callback = method(:handle_error)
      Test.abort_on_exception = false
      @frame.addWidget(@script_runner_frame)

      setCentralWidget(@central_widget)

      # Display a blank message to force the statusBar to show
      statusBar.showMessage("")
    end

    def status_timeout
      pass_count = TestStatus.instance.pass_count
      skip_count = TestStatus.instance.skip_count
      fail_count = TestStatus.instance.fail_count
      @test_status.text = TestStatus.instance.status
      @pass_count.text = pass_count.to_s
      @skip_count.text = skip_count.to_s
      @fail_count.text = fail_count.to_s
      if TestStatus.instance.status != ''
        run_count = pass_count + skip_count + fail_count
        total_count = TestStatus.instance.total
        mod_run_count = run_count % total_count
        progress = ((mod_run_count.to_f / total_count) * 100.0).to_i
        @progress_bar.setValue(progress)
      else
        @progress_bar.setValue(0)
      end
    end

    def self.results_writer
      @@results_writer
    end

    def self.exec_test(result_string, test_suite_class, test_class = nil, test_case = nil)
      @@started_success = false
      @@test_suites.each do |test_suite|
        if test_suite.class == test_suite_class
          @@started_success = @@results_writer.collect_metadata(@@instance)
          if @@started_success
            @@results_writer.start(result_string, test_suite_class, test_class, test_case, @@settings)
            loop do
              yield(test_suite)
              break if not @@settings['Loop Testing'] or (TestStatus.instance.fail_count > 0 and @@settings['Break Loop after Error'])
            end
          end
          break
        end
      end
    end

    def self.start(test_suite_class, test_class = nil, test_case = nil)
      result = []
      exec_test('', test_suite_class, test_class, test_case) do |test_suite|
        if test_case
          result = test_suite.run_test_case(test_class, test_case)
          @@results_writer.process_result(result)
          raise StopScript if (result.exceptions and Test.abort_on_exception) or result.stopped
        elsif test_class
          test_suite.run_test(test_class) { |current_result| @@results_writer.process_result(current_result); raise StopScript if current_result.stopped }
        else
          test_suite.run { |current_result| @@results_writer.process_result(current_result); raise StopScript if current_result.stopped }
        end
      end
    end

    def self.start_setup(test_suite_class, test_class = nil)
      exec_test('Manual Setup', test_suite_class, test_class) do |test_suite|
        if test_class
          result = test_suite.run_test_setup(test_class)
        else
          result = test_suite.run_setup
        end
        if result
          @@results_writer.process_result(result)
          raise StopScript if result.stopped
        end
      end
    end

    def self.start_teardown(test_suite_class, test_class = nil)
      exec_test('Manual Teardown', test_suite_class, test_class) do |test_suite|
        if test_class
          result = test_suite.run_test_teardown(test_class)
        else
          result = test_suite.run_teardown
        end
        if result
          @@results_writer.process_result(result)
          raise StopScript if result.stopped
        end
      end
    end

    # Called by cosmos_script_module by the user calling the status_bar scripting method
    def script_set_status(message)
      Qt.execute_in_main_thread(true) do
        # Check for self.disposed? to work around crash when using SimpleCov
        unless self.disposed?
          status_bar = statusBar()
          status_bar.showMessage(message)
        end
      end
    end

    def continue_without_pausing_on_errors?
      if !@pause_on_error.isChecked()
        msg = ""
        if @continue_test_case_after_error.isChecked() and @abort_testing_after_error.isChecked()
          msg = "the currently executing test case will run to completion before aborting"
        elsif !@continue_test_case_after_error.isChecked() and @abort_testing_after_error.isChecked()
          msg = "all testing will be aborted on an error"
        elsif @continue_test_case_after_error.isChecked() and !@abort_testing_after_error.isChecked()
          msg = "all testing will run to completion"
        else
          msg = "the next test case will start executing"
        end

        if Qt::MessageBox.warning(self, "Warning", "If an error occurs, testing will not pause and #{msg}. Continue?", Qt::MessageBox::Yes | Qt::MessageBox::No, Qt::MessageBox::Yes) == Qt::MessageBox::No
          return false
        end
      end
      true
    end

    def continue_loop_testing?
      if @loop_testing.isChecked()
        msg = ""
        if @break_loop_after_error.isChecked()
          msg = "unless an error occurs"
        else
          msg = "until explicitly stopped"
        end

        if Qt::MessageBox.warning(self, "Warning", "Loop testing is enabled. Tests will run forever #{msg}. Continue?", Qt::MessageBox::Yes | Qt::MessageBox::No, Qt::MessageBox::Yes) == Qt::MessageBox::No
          return false
        end
      end
      true
    end

    ###########################################
    # Callbacks
    ###########################################

    def generic_handler(test_suite, test = nil, test_case = nil, warnings = true)
      if warnings
        return unless continue_without_pausing_on_errors?
        return unless continue_loop_testing?()
      end

      # TODO: This can take a while depending on the number of tests and their
      # complexity. Consider making a progress bar for this.
      begin
        require_utilities()
        handle_check_buttons()
        @script_runner_frame.stop_message_log
        yield
        @script_runner_frame.run
      rescue Exception => error
        ExceptionDialog.new(self, error, "Error starting test", false)
      end
    end

    def handle_start(test_suite, test = nil, test_case = nil, warnings = true)
      generic_handler(test_suite, test, test_case, warnings) do
        if test_case
          @script_runner_frame.set_text("TestRunner.start(#{test_suite}, #{test}, '#{test_case}')", "#{test_suite}_#{test}_#{test_case}")
        elsif test
          @script_runner_frame.set_text("TestRunner.start(#{test_suite}, #{test})", "#{test_suite}_#{test}")
        else
          @script_runner_frame.set_text("TestRunner.start(#{test_suite})", test_suite)
        end
      end
    end

    def handle_setup(test_suite, test = nil)
      generic_handler(test_suite, test) do
        if test
          @script_runner_frame.set_text("TestRunner.start_setup(#{test_suite}, #{test})", "#{test_suite}_#{test}_setup")
        else
          @script_runner_frame.set_text("TestRunner.start_setup(#{test_suite})", "#{test_suite}_setup")
        end
      end
    end

    def handle_teardown(test_suite, test = nil)
      generic_handler(test_suite, test) do
        if test
          @script_runner_frame.set_text("TestRunner.start_teardown(#{test_suite}, #{test})", "#{test_suite}_#{test}_teardown")
        else
          @script_runner_frame.set_text("TestRunner.start_teardown(#{test_suite})", "#{test_suite}_teardown")
        end
      end
    end

    def handle_check_buttons
      if @pause_on_error.isChecked()
        ScriptRunnerFrame.pause_on_error = true
      else
        ScriptRunnerFrame.pause_on_error = false
      end

      if @continue_test_case_after_error.isChecked()
        @script_runner_frame.continue_after_error = true
      else
        @script_runner_frame.continue_after_error = false
      end

      if @abort_testing_after_error.isChecked()
        Test.abort_on_exception = true
      else
        Test.abort_on_exception = false
      end

      @@settings['Pause on Error'] = @pause_on_error.isChecked()
      @@settings['Continue Test Case after Error'] = @continue_test_case_after_error.isChecked()
      @@settings['Abort Testing after Error'] = @abort_testing_after_error.isChecked()
      @@settings['Manual'] = @manual.isChecked()
      @@settings['Loop Testing'] = @loop_testing.isChecked()
      @@settings['Break Loop after Error'] = @break_loop_after_error.isChecked()

      disable_while_running()
    end

    def handle_stop(script_runner_frame)
      if @@started_success
        @@results_writer.complete
        if @@results_writer.data_package
          ProgressDialog.execute(self, 'Data Package Creation Progress', 600, 300) do |progress_dialog|
            @@results_writer.create_data_package(progress_dialog)
          end
        end
      end
      enable_while_stopped()
      show_results() if @@started_success
    end

    def handle_error(script_runner_frame)
      Qt.execute_in_main_thread(true) do
        if @@settings['Continue Test Case after Error']
          script_runner_frame.enable_retry()
        else
          script_runner_frame.disable_retry()
        end
      end
    end

    def disable_while_running
      TestStatus.instance.status = ''
      TestStatus.instance.pass_count = 0
      TestStatus.instance.skip_count = 0
      TestStatus.instance.fail_count = 0
      @manual.setEnabled(false)
      @pause_on_error.setEnabled(false)
      @continue_test_case_after_error.setEnabled(false)
      @abort_testing_after_error.setEnabled(false)
      @loop_testing.setEnabled(false)
      @break_loop_after_error.setEnabled(false)
      @test_runner_chooser.setEnabled(false)
      @show_last.setEnabled(false)
      @select.setEnabled(false)
      @test_results_log_message.setEnabled(true)
      @script_log_message.setEnabled(true)
      @show_call_stack.setEnabled(true)
    end

    def enable_while_stopped
      @manual.setEnabled(true)
      @pause_on_error.setEnabled(true)
      @continue_test_case_after_error.setEnabled(true)
      @abort_testing_after_error.setEnabled(true)
      @loop_testing.setEnabled(true)
      @break_loop_after_error.setEnabled(true) if @loop_testing.isChecked()
      @test_runner_chooser.setEnabled(true)
      @show_last.setEnabled(true)
      @select.setEnabled(true)
      @test_results_log_message.setEnabled(false)
      @script_log_message.setEnabled(false)
      @show_call_stack.setEnabled(false)
      TestStatus.instance.status = ''
    end

    def closeEvent(event)
      if @script_runner_frame.prompt_if_running_on_close()
        shutdown_cmd_tlm()
        @script_runner_frame.stop_message_log
        super(event)
      else
        event.ignore()
      end
    end

    def on_test_results_log_message
      message = get_scriptrunner_log_message('Test Results Text Entry', 'Enter text to log to the test results file')
      if message
        Cosmos::Test.puts('User logged: '  + message.to_s)
        @script_runner_frame.handle_output_io
      end
    end

    def on_script_log_message
      message = get_scriptrunner_log_message()
      if message
        @script_runner_frame.scriptrunner_puts 'User logged: '  + message.to_s
        @script_runner_frame.handle_output_io
      end
    end

    def on_script_call_stack
      trace = @script_runner_frame.current_backtrace
      ScrollTextDialog.new(self, 'Call Stack', trace.join("\n"))
    end

    def on_script_toggle_debug
      @script_runner_frame.toggle_debug
    end

    def on_script_toggle_disconnect
      @server_config_file = @script_runner_frame.toggle_disconnect(@server_config_file)
    end

    include ScriptAudit # script_audit()

    def require_utilities
      ScriptRunnerFrame.instance = @script_runner_frame
      build = false
      @utilities.each do |utility|
        if require_utility(utility)
          build = true
        end
      end
      if build
        build_test_suites()
      end
      ScriptRunnerFrame.instance = nil
    end

    # Show Dialog box with textfield containing results
    def show_results
      if @@results_writer.filename
        results_text = File.read(@@results_writer.filename)

        dialog = Qt::Dialog.new(self) do |box|
          box.setWindowTitle('Results')
          box.resize(600, 600)
          text_field = Qt::PlainTextEdit.new
          text_field.setReadOnly(true)
          orig_font = text_field.font
          text_field.setFont(Cosmos.getFont(orig_font.family, orig_font.point_size+2))
          text_field.setWordWrapMode(Qt::TextOption::NoWrap)
          state = :NORMAL
          results_text.each_line do |line|
            state = :NORMAL if line[0..0] != ' ' and line.strip.length != 0
            if line =~ /:PASS/
              text_field.appendText(line, Cosmos::GREEN)
              state = :PASS
            elsif line =~ /:SKIP/
              text_field.appendText(line, Cosmos::YELLOW)
              state = :SKIP
            elsif line =~ /:FAIL/
              text_field.appendText(line, Cosmos::RED)
              state = :FAIL
            else
              case state
              when :NORMAL
                text_field.appendText(line)
              when :PASS
                text_field.appendText(line, Cosmos::GREEN)
              when :SKIP
                text_field.appendText(line, Cosmos::YELLOW)
              when :FAIL
                text_field.appendText(line, Cosmos::RED)
              end
            end
          end

          vframe = Qt::VBoxLayout.new
          vframe.addWidget(text_field)

          # Separator Between checkboxes
          sep = Qt::Frame.new(box)
          sep.setFrameStyle(Qt::Frame::VLine | Qt::Frame::Sunken)
          vframe.addWidget(sep)

          ok = Qt::PushButton.new('OK')
          ok.setDefault(true)
          ok.connect(SIGNAL('clicked(bool)')) { box.accept }
          vframe.addWidget(ok)
          box.setLayout(vframe)
        end
        dialog.exec
        dialog.dispose
      end
    end

    def create_node(yard_doc, name, tree)
      node = Qt::TreeWidgetItem.new([name])
      node.setCheckState(0, Qt::Unchecked)
      yield node
      description = yard_doc.nil? ? "" : yard_doc.docstring
      description = UNASSIGNED_SUITE_DESCRIPTION if name == "UnassignedTestSuite"
      desc_label = Qt::Label.new(description.gsub(/\n/,' '))
      desc_label.setMinimumHeight(desc_label.fontMetrics.height * 2)
      desc_label.setWordWrap(true)
      tree.setItemWidget(node, 1, desc_label)
      return node
    end

    # Show Dialog box with tree of tests to allow the user to select
    # a subset of tests. This also shows the Test Descriptions.
    def show_select
      dialog = Qt::Dialog.new(self) do |box|
        box.setWindowTitle('Test Selections')
        box.resize(650, 600)
        @procedure_dirs.each do |dir|
          # Set the logging level to ERROR to avoid output if one of the
          # scripts we are parsing has syntax errors
          YARD.parse(File.join(dir, '**', '*.rb'), [], YARD::Logger::ERROR)
        end

        tree = Qt::TreeWidget.new
        tree.setColumnCount(2)
        tree.setHeaderLabels(["Name", "Description"])
        tree.connect(SIGNAL('itemClicked(QTreeWidgetItem*, int)')) do |widget, column|
          tree.topLevelItems do |suite_node|
            if suite_node != widget.topLevel
              suite_node.setCheckStateAll(Qt::Unchecked)
            end
          end
        end

        orig_font = nil
        @@test_suites.each do |suite|
          next if suite.name == "CustomTestSuite"
          doc = YARD::Registry.resolve(nil, suite.name)
          suite_node = create_node(doc, suite.name, tree) do |node|
            orig_font = node.font(0)
            new_font = Cosmos.getFont(orig_font.family,
                                      orig_font.point_size+5,
                                      Qt::Font::Bold)
            node.setFont(0, new_font)
            tree.addTopLevelItem(node)
          end

          if suite.respond_to? :setup
            doc = YARD::Registry.resolve(P(suite.name.to_s), "#setup", true)
            create_node(doc, "setup", tree) do |node|
              font = Cosmos.getFont(orig_font.family,
                                    orig_font.point_size,
                                    Qt::Font::Normal,
                                    true) # italic
              node.setFont(0, font)
              suite_node.addChild(node)
            end
          end

          suite.tests.each do |test_class, test|
            doc = YARD::Registry.resolve(nil, test.name)
            test_node = create_node(doc, test.name, tree) do |node|
              font = Cosmos.getFont(orig_font.family,
                                    orig_font.point_size + 2,
                                    Qt::Font::Bold)
              node.setFont(0, font)
              suite_node.addChild(node)
              node.setExpanded(true)
            end

            if test.respond_to? :setup
              doc = YARD::Registry.resolve(P(test_class.to_s), "#setup", true)
              create_node(doc, "setup", tree) do |node|
                font = Cosmos.getFont(orig_font.family,
                                      orig_font.point_size,
                                      Qt::Font::Normal,
                                      true) # italic
                node.setFont(0, font)
                test_node.addChild(node)
              end
            end

            test_class.test_cases.each do |tc|
              doc = YARD::Registry.resolve(P(test_class.to_s), "##{tc.to_s}", true)
              create_node(doc, tc.to_s, tree) do |node|
                test_node.addChild(node)
              end
            end

            if test.respond_to? :teardown
              doc = YARD::Registry.resolve(P(test_class.to_s), "#teardown", true)
              create_node(doc, "teardown", tree) do |node|
                font = Cosmos.getFont(orig_font.family,
                                      orig_font.point_size,
                                      Qt::Font::Normal,
                                      true) # italic
                node.setFont(0, font)
                test_node.addChild(node)
              end
            end
          end # suite.tests.each

          if suite.respond_to? :teardown
            doc = YARD::Registry.resolve(P(suite.name.to_s), "#teardown", true)
            create_node(doc, "teardown", tree) do |node|
              font = Cosmos.getFont(orig_font.family,
                                    orig_font.point_size,
                                    Qt::Font::Normal,
                                    true) # italic
              node.setFont(0, font)
              suite_node.addChild(node)
            end
          end
        end

        tree.resizeColumnToContents(0)
        dialog_layout = Qt::VBoxLayout.new
        text = "Select test cases to be run in a newly created 'CustomTestSuite'. "\
          "Note that tests can only be added from a single existing Test Suite. " \
          "Thus clicking on something in another Test Suite deselects anything " \
          "currently selected."
        instructions = Qt::Label.new(text)
        instructions.setWordWrap(true)
        dialog_layout.addWidget(instructions)
        dialog_layout.addWidget(tree)

        # Separator Between checkboxes
        sep = Qt::Frame.new(box)
        sep.setFrameStyle(Qt::Frame::VLine | Qt::Frame::Sunken)
        dialog_layout.addWidget(sep)

        button_box = Qt::DialogButtonBox.new(Qt::DialogButtonBox::Ok |
                                             Qt::DialogButtonBox::Cancel)
        connect(button_box, SIGNAL('rejected()'), box, SLOT('reject()'))
        connect(button_box, SIGNAL('accepted()')) do
          ScriptRunnerFrame.instance = @script_runner_frame
          Cosmos.module_eval("class CustomTestSuite < TestSuite; end")
          tree.topLevelItems do |suite_node|
            next if suite_node.checkState == Qt::Unchecked
            cur_suite = OpenStruct.new(:setup=>false, :teardown=>false, :tests=>{})
            suite = CustomTestSuite.new
            begin
              # Remove any previously defined suite setup methods
              CustomTestSuite.send(:remove_method, :setup)
            rescue NameError
              # NameError is raised if no setup method was defined
            end
            begin
              # Remove any previously defined suite teardown methods
              CustomTestSuite.send(:remove_method, :teardown)
            rescue NameError
              # NameError is raised if no teardown method was defined
            end

            suite_node.children do |test_node|
              if test_node.checkState == Qt::Checked
                if test_node.text == 'setup'
                  cur_suite.setup = true
                  # Find the suite instance among the test suites
                  inst = @@test_suites.detect {|my_suite| my_suite.class.to_s == suite_node.text}
                  # Create a lambda which will call that one setup method
                  body = lambda { inst.setup }
                  CustomTestSuite.send(:define_method, :setup, &body)
                end
                if test_node.text == 'teardown'
                  cur_suite.teardown = true
                  # Find the suite instance among the test suites
                  inst = @@test_suites.detect {|my_suite| my_suite.class.to_s == suite_node.text}
                  # Create a lambda which will call that one teardown method
                  body = lambda { inst.teardown}
                  CustomTestSuite.send(:define_method, :teardown, &body)
                end
              end

              test_node.children do |test_case|
                next if test_case.checkState == Qt::Unchecked
                node = cur_suite.tests[test_node.text] ||=
                  OpenStruct.new(:setup=>false, :teardown=>false, :cases=>[])

                case test_case.text
                when 'setup'
                  suite.add_test_setup(test_node.text)
                  node.setup = true
                when 'teardown'
                  suite.add_test_teardown(test_node.text)
                  node.teardown = true
                else
                  suite.add_test_case(test_node.text, test_case.text)
                  node.cases << test_case.text
                end
              end
            end
            @@suites["CustomTestSuite"] = cur_suite
            @@test_suites = @@test_suites.select {|my_suite| my_suite.class != CustomTestSuite}
            @@test_suites << suite
          end
          Qt.execute_in_main_thread(true) do
            @test_runner_chooser.test_suites = @@suites
            @test_runner_chooser.select_suite("CustomTestSuite")
          end
          ScriptRunnerFrame.instance = nil
          box.accept
        end
        dialog_layout.addWidget(button_box)
        box.setLayout(dialog_layout)
      end
      dialog.raise
      dialog.exec
      dialog.dispose
    end

    def file_options
      dialog = Qt::Dialog.new(self)
      dialog.setWindowTitle('Test Runner Options')
      layout = Qt::VBoxLayout.new

      form = Qt::FormLayout.new
      box = Qt::DoubleSpinBox.new
      box.setRange(0, 60)
      box.setValue(ScriptRunnerFrame.line_delay)
      form.addRow("&Delay between each script line:", box)
      monitor = Qt::CheckBox.new
      form.addRow("&Monitor limits:", monitor)
      pause_on_red = Qt::CheckBox.new
      form.addRow("Pause on &red limit:", pause_on_red)
      if ScriptRunnerFrame.monitor_limits
        monitor.setCheckState(Qt::Checked)
        pause_on_red.setCheckState(Qt::Checked) if ScriptRunnerFrame.pause_on_red
      else
        pause_on_red.setEnabled(false)
      end
      monitor.connect(SIGNAL('stateChanged(int)')) do
        if monitor.isChecked()
          pause_on_red.setEnabled(true)
        else
          pause_on_red.setCheckState(Qt::Unchecked)
          pause_on_red.setEnabled(false)
        end
      end
      layout.addLayout(form)

      divider = Qt::Frame.new
      divider.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Raised)
      divider.setLineWidth(1)
      layout.addWidget(divider)

      ok = Qt::PushButton.new('Ok')
      ok.setDefault(true)
      ok.connect(SIGNAL('clicked(bool)')) do
        ScriptRunnerFrame.line_delay = box.value
        ScriptRunnerFrame.monitor_limits = (monitor.checkState == Qt::Checked)
        ScriptRunnerFrame.pause_on_red = (pause_on_red.checkState == Qt::Checked)
        dialog.accept
      end
      cancel = Qt::PushButton.new('Cancel')
      cancel.connect(SIGNAL('clicked(bool)')) { dialog.reject }
      button_layout = Qt::HBoxLayout.new
      button_layout.addWidget(ok)
      button_layout.addWidget(cancel)
      layout.addLayout(button_layout)
      dialog.setLayout(layout)
      dialog.exec
      dialog.dispose
    end

    def process_config(filename)
      ScriptRunnerFrame.instance = @script_runner_frame
      # Remember all the requires that fail and warn the user
      require_errors = []

      parser = ConfigParser.new("http://cosmosrb.com/docs/tools/#test-runner-configuration")
      parser.parse_file(filename) do |keyword, params|
        case keyword
        # REQUIRE_UTILITY was deprecated > 4.3.0 but left for compatibility purposes
        when 'LOAD_UTILITY', 'REQUIRE_UTILITY'
          parser.verify_num_parameters(1, 1, "LOAD_UTILITY <filename>")
          begin
            require_utility params[0]
            @utilities << params[0]
          rescue Exception => err
            require_errors << "<b>#{params[0]}</b>:\n#{err.formatted}\n"
          end

        when 'RESULTS_WRITER'
          data_package = @@results_writer.data_package
          metadata = @@results_writer.metadata
          parser.verify_num_parameters(1, nil, "RESULTS_WRITER <filename> <class specific options>")
          results_class = Cosmos.require_class(params[0])
          if params[1]
            @@results_writer = results_class.new(*params[1..-1])
          else
            @@results_writer = results_class.new
          end
          @@results_writer.data_package = data_package
          @@results_writer.metadata = metadata

        when 'ALLOW_DEBUG'
          parser.verify_num_parameters(0, 0, "ALLOW_DEBUG")
          Qt.execute_in_main_thread(true) { @toggle_debug.setEnabled(true) }

        when 'PAUSE_ON_ERROR'
          parser.verify_num_parameters(1, 1, "#{keyword} <TRUE or FALSE>")
          Qt.execute_in_main_thread(true) do
            @pause_on_error.setChecked(ConfigParser.handle_true_false(params[0]))
          end

        when 'CONTINUE_TEST_CASE_AFTER_ERROR'
          parser.verify_num_parameters(1, 1, "#{keyword} <TRUE or FALSE>")
          Qt.execute_in_main_thread(true) { @continue_test_case_after_error.setChecked(ConfigParser.handle_true_false(params[0])) }

        when 'ABORT_TESTING_AFTER_ERROR'
          parser.verify_num_parameters(1, 1, "#{keyword} <TRUE or FALSE>")
          Qt.execute_in_main_thread(true) { @abort_testing_after_error.setChecked(ConfigParser.handle_true_false(params[0])) }

        when 'MANUAL'
          parser.verify_num_parameters(1, 1, "#{keyword} <TRUE or FALSE>")
          Qt.execute_in_main_thread(true) do
            @manual.setChecked(ConfigParser.handle_true_false(params[0]))
            if @manual.isChecked()
              $manual = true
            else
              $manual = false
            end
          end

        when 'LOOP_TESTING'
          parser.verify_num_parameters(1, 1, "#{keyword} <TRUE or FALSE>")
          Qt.execute_in_main_thread(true) do
            @loop_testing.setChecked(ConfigParser.handle_true_false(params[0]))
            if @loop_testing.isChecked()
              $loop_testing = true
              @break_loop_after_error.setEnabled(true)
            else
              $loop_testing = false
              @break_loop_after_error.setEnabled(false)
            end
          end

        when 'BREAK_LOOP_AFTER_ERROR'
          parser.verify_num_parameters(1, 1, "#{keyword} <TRUE or FALSE>")
          Qt.execute_in_main_thread(true) { @break_loop_after_error.setChecked(ConfigParser.handle_true_false(params[0])) }

        when 'IGNORE_TEST'
          parser.verify_num_parameters(1, 1, "#{keyword} <Test Class Name (case sensitive)>")
          @ignore_tests << params[0]

        when 'IGNORE_TEST_SUITE'
          parser.verify_num_parameters(1, 1, "#{keyword} <Test Suite Class Name (case sensitive)>")
          @ignore_test_suites << params[0]

        when 'LINE_DELAY'
          parser.verify_num_parameters(1, 1, "#{keyword} <Line Delay in Seconds>")
          ScriptRunnerFrame.line_delay = params[0].to_f

        when 'MONITOR_LIMITS'
          parser.verify_num_parameters(0, 0, keyword)
          ScriptRunnerFrame.monitor_limits = true

        when 'PAUSE_ON_RED'
          parser.verify_num_parameters(0, 0, keyword)
          ScriptRunnerFrame.monitor_limits = true
          ScriptRunnerFrame.pause_on_red = true

        when 'CREATE_DATA_PACKAGE'
          parser.verify_num_parameters(0, 0, keyword)
          @@results_writer.data_package = true

        when 'AUTO_CYCLE_LOGS'
          parser.verify_num_parameters(0, 0, keyword)
          @@results_writer.auto_cycle_logs = true

        when 'COLLECT_METADATA'
          parser.verify_num_parameters(0, 0, "#{keyword}")
          @@results_writer.metadata = true

        when 'DISABLE_TEST_SUITE_START'
          parser.verify_num_parameters(0, 0, "#{keyword}")
          Qt.execute_in_main_thread { @test_runner_chooser.test_suite_start_disabled = true }

        when 'DISABLE_TEST_GROUP_START'
          parser.verify_num_parameters(0, 0, "#{keyword}")
          Qt.execute_in_main_thread { @test_runner_chooser.test_group_start_disabled = true }

        else
          raise "Unhandled keyword: #{keyword}" if keyword
        end
      end

      # Warn the user about all the requires that failed
      unless require_errors.empty?
        Qt.execute_in_main_thread(true) do
          message = "While loading the Test Runner configuration file: #{filename}."
          message << "\n\nThe following errors occurred:\n#{require_errors.join("\n")}" unless require_errors.empty?
          ScrollTextDialog.new(self, "TestRunner Errors", message)
        end
      end

      # Build Test objects
      build_test_suites()

      ScriptRunnerFrame.instance = nil
    end

    def build_test_suites
      ScriptRunnerFrame.instance.use_instrumentation = false

      ignored_test_classes = []
      ignored_test_suite_classes = []

      @ignore_tests.each do |test_name|
        begin
          klass = Object.const_get(test_name)
          ignored_test_classes << klass if klass
        rescue
        end
      end

      @ignore_test_suites.each do |test_suite_name|
        begin
          klass = Object.const_get(test_suite_name)
          ignored_test_suite_classes << klass if klass
        rescue
        end
      end

      # Build list of TestSuites and Tests
      @@test_suites = @@test_suites.select {|my_suite| my_suite.name == 'CustomTestSuite'}
      tests = []
      ObjectSpace.each_object(Class) do |object|

        begin
          next if object.name == 'CustomTestSuite'
          ancestors = object.ancestors
        rescue
          # Ignore Classes where name or ancestors may raise exception
          # Bundler::Molinillo::DependencyGraph::Action is one example
          next
        end
        if (ancestors.include?(TestSuite) &&
            object != TestSuite &&
            !ignored_test_suite_classes.include?(object))
          # Ensure they didn't override name for some reason
          if object.instance_methods(false).include?(:name)
            raise FatalError.new("#{object} redefined the 'name' method. Delete the 'name' method and try again.")
          end
          # ObjectSpace.each_object appears to yield objects in the reverse
          # order that they were parsed by the interpreter so push each
          # TestSuite object to the front of the array to order as encountered
          @@test_suites.unshift(object.new)
        end
        if (ancestors.include?(Test) &&
            object != Test &&
            !ignored_test_classes.include?(object))
          # Ensure they didn't override self.name for some reason
          if object.methods(false).include?(:name)
            raise FatalError.new("#{object} redefined the 'self.name' method. Delete the 'self.name' method and try again.")
          end
          tests << object
        end
      end
      # Raise error if no test suites or tests
      if @@test_suites.empty? || tests.empty?
        msg = "No TestSuites or no Test classes found"
        if !ignored_test_suite_classes.empty?
          msg << "\n\nThe following TestSuites were found but ignored:\n#{ignored_test_suite_classes.join(", ")}"
        end
        if !ignored_test_classes.empty?
          msg << "\n\nThe following Tests were found but ignored:\n#{ignored_test_classes.join(", ")}"
        end
        Qt.execute_in_main_thread(true) do
          Qt::MessageBox.critical(self, 'Error', msg)
        end
        exit 1
      end

      # Create TestSuite for unassigned Tests
      @@test_suites.each do |test_suite|
        tests_to_delete = []
        tests.each { |test| tests_to_delete << test if test_suite.tests[test] }
        tests_to_delete.each { |test| tests.delete(test) }
      end
      if tests.empty?
        @@test_suites = @@test_suites.select {|suite| suite.class != UnassignedTestSuite}
      else
        uts = @@test_suites.select {|suite| suite.class == UnassignedTestSuite}[0]
        tests.each { |test| uts.add_test(test) }
      end

      ScriptRunnerFrame.instance.use_instrumentation = true
      @@test_suites.each do |suite|
        cur_suite = OpenStruct.new(:setup=>false, :teardown=>false, :tests=>{})
        cur_suite.setup = true if suite.class.method_defined?(:setup)
        cur_suite.teardown = true if suite.class.method_defined?(:teardown)

        suite.plans.each do |test_type, test_class, test_case|
          case test_type
          when :TEST
            cur_suite.tests[test_class.name] ||=
              OpenStruct.new(:setup=>false, :teardown=>false, :cases=>[])
            cur_suite.tests[test_class.name].cases.concat(test_class.test_cases)
            cur_suite.tests[test_class.name].cases.uniq!
            cur_suite.tests[test_class.name].setup = true if test_class.method_defined?(:setup)
            cur_suite.tests[test_class.name].teardown = true if test_class.method_defined?(:teardown)
          when :TEST_CASE
            cur_suite.tests[test_class.name] ||=
              OpenStruct.new(:setup=>false, :teardown=>false, :cases=>[])
            # Explicitly check for this method and raise an error if it does not exist
            if test_class.method_defined?(test_case.intern)
              cur_suite.tests[test_class.name].cases << test_case
              cur_suite.tests[test_class.name].cases.uniq!
            else
              raise "#{test_class} does not have a #{test_case} method defined."
            end
            cur_suite.tests[test_class.name].setup = true if test_class.method_defined?(:setup)
            cur_suite.tests[test_class.name].teardown = true if test_class.method_defined?(:teardown)
          when :TEST_SETUP
            cur_suite.tests[test_class.name] ||=
              OpenStruct.new(:setup=>false, :teardown=>false, :cases=>[])
            # Explicitly check for the setup method and raise an error if it does not exist
            if test_class.method_defined?(:setup)
              cur_suite.tests[test_class.name].setup = true
            else
              raise "#{test_class} does not have a setup method defined."
            end
          when :TEST_TEARDOWN
            cur_suite.tests[test_class.name] ||=
              OpenStruct.new(:setup=>false, :teardown=>false, :cases=>[])
            # Explicitly check for the teardown method and raise an error if it does not exist
            if test_class.method_defined?(:teardown)
              cur_suite.tests[test_class.name].teardown = true
            else
              raise "#{test_class} does not have a teardown method defined."
            end
          end
        end
        @@suites[suite.name.split('::')[-1]] = cur_suite unless suite.name == 'CustomTestSuite'
      end
      Qt.execute_in_main_thread(true) { @test_runner_chooser.test_suites = @@suites }
    end

    def self.run(option_parser = nil, options = nil)
      Cosmos.catch_fatal_exception do
        unless option_parser and options
          option_parser, options = create_default_options()
          options.width = 800
          options.height = 700
          options.title = "Test Runner"
          options.auto_size = false
          options.server_config_file = CmdTlmServer::DEFAULT_CONFIG_FILE
          options.config_file = true # config_file is required
          option_parser.separator "Test Runner Specific Options:"
          option_parser.on("-s", "--server FILE", "Use the specified server configuration file for disconnect mode") do |arg|
            options.server_config_file = arg
          end
          option_parser.on("--suite SUITE", "Start the specified test suite.") do |arg|
            options.test_suite = arg
          end
          option_parser.on("--group GROUP", "Start the specified test group. Requires the --suite option.") do |arg|
            unless options.test_suite
              puts option_parser
              exit
            end
            options.test_group = arg
          end
          option_parser.on("--case CASE", "Start the specified test case. Requires the --suite and --group options.") do |arg|
            unless options.test_suite && options.test_group
              puts option_parser
              exit
            end
            options.test_case = arg
          end
        end

        super(option_parser, options)
      end
    end
  end
end
