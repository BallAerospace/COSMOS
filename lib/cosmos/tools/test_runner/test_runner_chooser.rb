# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'

module Cosmos

  # Qt Widget used by the Cosmos::TestRunner application.
  # It constructs a list of Test Suites, Test Groups, and
  # Test Cases in combo box choosers. All combo boxes are folowed by
  # Start buttons and Suites and Groups also have Setup and Teardown
  # buttons. When a new Test Suite is choosen the Test Group and
  # Test Case combo boxes update. When a Test Group is changed the
  # Test Case combo box is updated.
  class TestRunnerChooser < Qt::Widget

    # Width of the button in the Combobox
    COMBOBOX_BUTTON_WIDTH = 30

    # Callback called when the target is changed - call(test_suite)
    attr_accessor :test_suite_changed_callback

    # Callback called when the test is changed - call(test_suite, test)
    attr_accessor :test_changed_callback

    # Callback called when the test_case is changed - call(test_suite, test, test_case)
    attr_accessor :test_case_changed_callback

    # Callback called when the test suite start button is pressed - call(test_suite)
    attr_accessor :test_suite_start_callback

    # Callback called when the test start button is pressed - call(test_suite, test)
    attr_accessor :test_start_callback

    # Callback called when the test case start button is pressed - call(test_suite, test, test_case)
    attr_accessor :test_case_start_callback

    # Callback called when the test suite setup button is pressed - call(test_suite)
    attr_accessor :test_suite_setup_callback

    # Callback called when the test setup button is pressed - call(test_suite, test)
    attr_accessor :test_setup_callback

    # Callback called when the test suite teardown button is pressed - call(test_suite)
    attr_accessor :test_suite_teardown_callback

    # Callback called when the test teardown button is pressed - call(test_suite, test)
    attr_accessor :test_teardown_callback

    # Whether the suite and group start button is disabled
    attr_reader :test_suite_start_disabled, :test_group_start_disabled

    # Constructor
    def initialize(parent)
      super(parent)

      @overall = Qt::GridLayout.new
      @overall.setContentsMargins(0,0,0,0)

      start_button_width = 60
      setup_button_width = 60
      teardown_button_width = 60

      @test_suite_start_disabled = false
      @test_group_start_disabled = false

      # Test Suite Selection
      @test_suite_combobox = Qt::ComboBox.new
      @test_suite_combobox.setSizePolicy(Qt::SizePolicy::Minimum, Qt::SizePolicy::Minimum)
      @test_suite_combobox.setSizeAdjustPolicy(Qt::ComboBox::AdjustToContents)
      @test_suite_completion = Completion.new(@test_suite_combobox)
      @test_suite_combobox.setCompleter(@test_suite_completion)
      @test_suite_start_button = Qt::PushButton.new('Start')
      @test_suite_start_button.setFixedWidth(start_button_width)
      @test_suite_setup_button = Qt::PushButton.new('Setup')
      @test_suite_setup_button.setFixedWidth(setup_button_width)
      @test_suite_teardown_button = Qt::PushButton.new('Teardown')
      @test_suite_teardown_button.setFixedWidth(teardown_button_width)
      @test_suite_label = Qt::Label.new("Test Suite:")
      @overall.addWidget(@test_suite_label, 0, 0)
      @overall.addWidget(@test_suite_combobox, 0, 1)
      @overall.addWidget(@test_suite_start_button, 0, 2)
      @overall.addWidget(@test_suite_setup_button, 0, 3)
      @overall.addWidget(@test_suite_teardown_button, 0, 4)

      # Test Group Selection
      @test_combobox = Qt::ComboBox.new
      @test_combobox.setSizePolicy(Qt::SizePolicy::Minimum, Qt::SizePolicy::Minimum)
      @test_combobox.setSizeAdjustPolicy(Qt::ComboBox::AdjustToContents)
      @test_completion = Completion.new(@test_combobox)
      @test_combobox.setCompleter(@test_completion)
      @test_start_button = Qt::PushButton.new('Start')
      @test_start_button.setFixedWidth(start_button_width)
      @test_setup_button = Qt::PushButton.new('Setup')
      @test_setup_button.setFixedWidth(setup_button_width)
      @test_teardown_button = Qt::PushButton.new('Teardown')
      @test_teardown_button.setFixedWidth(teardown_button_width)
      @test_label = Qt::Label.new("Test Group:")
      @overall.addWidget(@test_label, 1, 0)
      @overall.addWidget(@test_combobox, 1, 1)
      @overall.addWidget(@test_start_button, 1, 2)
      @overall.addWidget(@test_setup_button, 1, 3)
      @overall.addWidget(@test_teardown_button, 1, 4)

      # Test Case Selection
      @test_case_combobox = Qt::ComboBox.new
      @test_case_combobox.setSizePolicy(Qt::SizePolicy::Minimum, Qt::SizePolicy::Minimum)
      @test_case_combobox.setSizeAdjustPolicy(Qt::ComboBox::AdjustToContents)
      @test_case_completion = Completion.new(@test_case_combobox)
      @test_case_combobox.setCompleter(@test_case_completion)
      @test_case_start_button = Qt::PushButton.new('Start')
      @test_case_start_button.setFixedWidth(start_button_width)
      @test_case_label = Qt::Label.new("Test Case:")
      @overall.addWidget(@test_case_label, 2, 0)
      @overall.addWidget(@test_case_combobox, 2, 1)
      @overall.addWidget(@test_case_start_button, 2, 2)
      @blank_label1 = Qt::Label.new('')
      @overall.addWidget(@blank_label1, 2, 3)
      @blank_label2 = Qt::Label.new('')
      @overall.addWidget(@blank_label2, 2, 4)

      setLayout(@overall)

      # Disable buttons
      @test_suite_start_button.setEnabled(false)
      @test_suite_setup_button.setEnabled(false)
      @test_suite_teardown_button.setEnabled(false)
      @test_start_button.setEnabled(false)
      @test_setup_button.setEnabled(false)
      @test_teardown_button.setEnabled(false)
      @test_case_start_button.setEnabled(false)

      # Connect handlers
      @test_suite_combobox.connect(SIGNAL('activated(int)')) { handle_test_suite_change }
      @test_combobox.connect(SIGNAL('activated(int)')) { handle_test_change }
      @test_case_combobox.connect(SIGNAL('activated(int)')) { handle_test_case_change }
      @test_suite_start_button.connect(SIGNAL('clicked(bool)')) { handle_test_suite_start_button }
      @test_start_button.connect(SIGNAL('clicked(bool)')) { handle_test_start_button }
      @test_case_start_button.connect(SIGNAL('clicked(bool)')) { handle_test_case_start_button }
      @test_suite_setup_button.connect(SIGNAL('clicked(bool)')) { handle_test_suite_setup_button }
      @test_setup_button.connect(SIGNAL('clicked(bool)')) { handle_test_setup_button }
      @test_suite_teardown_button.connect(SIGNAL('clicked(bool)')) { handle_test_suite_teardown_button }
      @test_teardown_button.connect(SIGNAL('clicked(bool)')) { handle_test_teardown_button }

      # Initialize instance variables
      @test_suite_changed_callback = nil
      @test_changed_callback = nil
      @test_case_changed_callback = nil
      @test_suite_start_callback = nil
      @test_start_callback = nil
      @test_case_start_callback = nil
      @test_suite_setup_callback = nil
      @test_setup_callback = nil
      @test_suite_teardown_callback = nil
      @test_teardown_callback = nil
    end

    def test_suite_start_disabled=(bool)
      @test_suite_start_disabled = bool
      if @test_suite_start_disabled
        @test_suite_start_button.setEnabled(false)
      end
    end

    def test_group_start_disabled=(bool)
      @test_group_start_disabled = bool
      if @test_group_start_disabled
        @test_start_button.setEnabled(false)
      end
    end

    def select_suite(test_suite)
      # setCurrentText searches for the given text and upon failure sets the
      # index to -1 which is safe
      @test_suite_combobox.setCurrentText(test_suite)
      handle_test_suite_change
    end

    # The test_suites parameter must be a hash of test suite names (String) pointing to
    # OpenStructs constructed as follows:
    #   OpenStruct.new(:setup=>false, :teardown=>false, :tests=>{})
    # The tests hash must be keyed by the test name (String) pointing to another OpenStruct
    # constructed as follows:
    #   OpenStruct.new(:setup=>false, :teardown=>false, :cases=>[])
    # Where cases is an array of test case names (Array of Strings)
    def test_suites=(test_suites)
      @test_suites = test_suites
      update_suites()
      update_tests()
      update_cases()
    end

    # Handle the test suite being changed
    def handle_test_suite_change
      update_suites()
      update_tests()
      update_cases()
      if @test_suite_changed_callback
        @test_suite_changed_callback.call(@test_suite_combobox.text)
      end
    end

    # Handle the test being changed
    def handle_test_change
      update_tests()
      update_cases()
      if @test_changed_callback
        @test_changed_callback.call(@test_suite_combobox.text, @test_combobox.text)
      end
    end

    # Handle the test case being changed
    def handle_test_case_change
      if @test_case_changed_callback
        @test_case_changed_callback.call(@test_suite_combobox.text, @test_combobox.text, @test_case_combobox.text)
      end
    end

    # Handle the test suite start button being pressed
    def handle_test_suite_start_button
      @test_suite_start_callback.call(@test_suite_combobox.text) if @test_suite_start_callback
    end

    # Handle the test start button being pressed
    def handle_test_start_button
      @test_start_callback.call(@test_suite_combobox.text, @test_combobox.text) if @test_start_callback
    end

    # Handle the test start case button being pressed
    def handle_test_case_start_button
      @test_case_start_callback.call(@test_suite_combobox.text, @test_combobox.text, @test_case_combobox.text) if @test_case_start_callback
    end

    # Handle the test suite setup button being pressed
    def handle_test_suite_setup_button
      @test_suite_setup_callback.call(@test_suite_combobox.text) if @test_suite_setup_callback
    end

    # Handle the test setup button being pressed
    def handle_test_setup_button
      @test_setup_callback.call(@test_suite_combobox.text, @test_combobox.text) if @test_setup_callback
    end

    # Handle the test suite teardown button being pressed
    def handle_test_suite_teardown_button
      @test_suite_teardown_callback.call(@test_suite_combobox.text) if @test_suite_teardown_callback
    end

    # Handle the test teardown button being pressed
    def handle_test_teardown_button
      @test_teardown_callback.call(@test_suite_combobox.text, @test_combobox.text) if @test_teardown_callback
    end

    protected

    def update_combobox(combobox, values)
      cur = combobox.text
      combobox.clearItems
      values.each do |val|
        combobox.addItem(val.to_s)
      end
      if values.length > 20
        combobox.setMaxVisibleItems(20)
      else
        combobox.setMaxVisibleItems(values.length)
      end
      if cur and values.include?(cur)
        combobox.setCurrentText(cur)
      else
        combobox.setCurrentIndex(0)
      end
    end

    # Updates test suites
    def update_suites
      update_combobox(@test_suite_combobox, @test_suites.keys)
      test_suite = @test_suites[@test_suite_combobox.text]
      if test_suite
        if test_suite.setup
          @test_suite_setup_button.setEnabled(true)
        else
          @test_suite_setup_button.setEnabled(false)
        end
        if test_suite.teardown
          @test_suite_teardown_button.setEnabled(true)
        else
          @test_suite_teardown_button.setEnabled(false)
        end
      end
      if @test_suites.keys.empty? || @test_suite_start_disabled
        @test_suite_start_button.setEnabled(false)
      else
        @test_suite_start_button.setEnabled(true)
      end
    end

    # Updates tests
    def update_tests
      test_suite = @test_suites[@test_suite_combobox.text]
      if test_suite
        update_combobox(@test_combobox, test_suite.tests.keys)
        # Adjust the test group combobox to match the test suite size
        #@test_combobox.setFixedWidth(@test_suite_combobox.sizeHint().width)

        if @test_combobox.text
          test = test_suite.tests[@test_combobox.text]
          if test
            if test.setup
              @test_setup_button.setEnabled(true)
            else
              @test_setup_button.setEnabled(false)
            end
            if test.teardown
              @test_teardown_button.setEnabled(true)
            else
              @test_teardown_button.setEnabled(false)
            end
          end
          @test_start_button.setEnabled(true) unless @test_group_start_disabled
        else
          @test_start_button.setEnabled(false)
        end
      end
    end

    # Updates test cases
    def update_cases
      names = []
      test_suite = @test_suites[@test_suite_combobox.text]
      test = @test_combobox.text
      if test_suite and test
        names = test_suite.tests[@test_combobox.text].cases
      end
      update_combobox(@test_case_combobox, names)
      # Adjust the test case combobox to match the test suite size
      #@test_case_combobox.setFixedWidth(@test_suite_combobox.sizeHint().width)

      if names.empty?
        @test_case_start_button.setEnabled(false)
      else
        @test_case_start_button.setEnabled(true)
      end
    end
  end # class TestRunnerChooser

end # module Cosmos
