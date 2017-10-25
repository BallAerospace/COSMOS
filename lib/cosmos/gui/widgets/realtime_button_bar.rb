# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the RealtimeButtonBar
# This provides a reusable set of realtime controls.

require 'cosmos'
require 'cosmos/gui/qt'

module Cosmos
  # Create a horizontal or vertical widget which contains buttons to control
  # scripting. The Step button is hidden by default, and Start, Pause, and
  # Stop are visible.
  class RealtimeButtonBar < Qt::Widget
    attr_accessor :step_callback
    attr_accessor :start_callback
    attr_accessor :pause_callback
    attr_accessor :stop_callback
    attr_reader :step_button
    attr_reader :start_button
    attr_reader :pause_button
    attr_reader :stop_button

    def initialize(parent, orientation = Qt::Horizontal)
      super(parent)
      if orientation == Qt::Horizontal
        # Horizontal Frame for overall widget
        @overall_frame = Qt::HBoxLayout.new(self)
        @state = Qt::LineEdit.new
      else
        # Vertical Frame for overall widget
        @overall_frame = Qt::VBoxLayout.new(self)
        @state = Qt::LineEdit.new
      end
      @overall_frame.setContentsMargins(0,0,0,0)
      @state.setAlignment(Qt::AlignCenter)
      @state.setText('Connecting')
      @state.setReadOnly(true)
      @overall_frame.addWidget(@state)

      if orientation == Qt::Horizontal
        @overall_frame.addStretch
        # Buttons
        @stop_button  = Qt::PushButton.new('Stop')
        @pause_button = Qt::PushButton.new('Pause')
        @start_button = Qt::PushButton.new('Start')
        @step_button  = Qt::PushButton.new('Step')
        @step_button.setHidden(true)
        @overall_frame.addWidget(@step_button)
        @overall_frame.addWidget(@start_button)
        @overall_frame.addWidget(@pause_button)
        @overall_frame.addWidget(@stop_button)
      else
        # Buttons
        @button_frame = Qt::HBoxLayout.new
        @step_button = Qt::PushButton.new('Step')
        @step_button.setHidden(true)
        @start_button = Qt::PushButton.new('Start')
        @pause_button = Qt::PushButton.new('Pause')
        @stop_button  = Qt::PushButton.new('Stop')
        @button_frame.addWidget(@step_button)
        @button_frame.addWidget(@start_button)
        @button_frame.addWidget(@pause_button)
        @button_frame.addWidget(@stop_button)
        @overall_frame.addLayout(@button_frame)
      end

      setLayout(@overall_frame)

      # Connect handlers
      @stop_button.connect(SIGNAL('clicked()')) { @stop_callback.call if @stop_callback }
      @pause_button.connect(SIGNAL('clicked()')) { @pause_callback.call if @pause_callback }
      @start_button.connect(SIGNAL('clicked()')) { @start_callback.call if @start_callback }
      @step_button.connect(SIGNAL('clicked()')) { @step_callback.call if @step_callback }

      @step_callback = nil
      @start_callback = nil
      @pause_callback = nil
      @stop_callback  = nil
    end

    # Returns the text in the state field
    def state
      return @state.text
    end

    # Sets the text in the state field
    def state= (new_state)
      @state.setText(new_state.to_s)
    end
  end
end
