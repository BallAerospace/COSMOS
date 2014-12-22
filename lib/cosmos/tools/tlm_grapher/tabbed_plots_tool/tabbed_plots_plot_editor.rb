# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/tlm_grapher/plot_editors/linegraph_plot_editor'
require 'cosmos/tools/tlm_grapher/plot_editors/xy_plot_editor'
require 'cosmos/tools/tlm_grapher/plot_editors/singlexy_plot_editor'

module Cosmos

  # Dialog to edit the plot
  class TabbedPlotsPlotEditor < Qt::Dialog

    def initialize(parent, title, plot_types, plot = nil)
      super(parent)
      setWindowTitle(title)

      @layout = Qt::VBoxLayout.new

      unless plot
        # Create combobox to select plot type
        @combobox = Qt::ComboBox.new(self)
        plot_types.each {|plot_type| @combobox.addItem(plot_type.to_s.upcase)}
        @combobox.setMaxVisibleItems(plot_types.length)
        @combobox.connect(SIGNAL('currentIndexChanged(int)')) { handle_plot_type_change() }
        @combo_layout = Qt::FormLayout.new()
        @combo_layout.addRow('Plot Type:', @combobox)
        @layout.addLayout(@combo_layout)

        # Separator before actual editing dialog
        @sep1 = Qt::Frame.new
        @sep1.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
        @layout.addWidget(@sep1)
      else
        setWindowTitle(title + " : #{plot.plot_type}")
      end

      # Create editor class for specific plot type
      # Defaults to plot_types[0] if a plot was not given
      if plot
        plot_type = plot.class.to_s[0..-5].downcase
        plot_type = plot_type.split('::')[-1] # Remove Cosmos:: if present
      else
        plot_type = plot_types[0].to_s.downcase
      end
      @editor_layout = Qt::VBoxLayout.new
      @layout.addLayout(@editor_layout)
      @editor = Cosmos.require_class(plot_type + '_plot_editor').new(self, plot)
      @editor_layout.addWidget(@editor)

      # Separator before buttons
      @sep2 = Qt::Frame.new
      @sep2.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
      @layout.addWidget(@sep2)
      @layout.addStretch

      # Create OK and Cancel buttons
      @ok_button = Qt::PushButton.new('Ok')
      @ok_button.setDefault(true)
      connect(@ok_button, SIGNAL('clicked()'), self, SLOT('accept()'))
      @cancel_button = Qt::PushButton.new('Cancel')
      connect(@cancel_button, SIGNAL('clicked()'), self, SLOT('reject()'))
      @button_layout = Qt::HBoxLayout.new()
      @button_layout.addWidget(@ok_button)
      @button_layout.addWidget(@cancel_button)
      @layout.addLayout(@button_layout)
      @ok_button.setDefault(true)

      setLayout(@layout)
    end # def initialize

    # Executes the plot editor dialog box
    def execute
      return_value = nil
      result = exec()
      if result == Qt::Dialog::Accepted
        return_value = @editor.plot
      end
      return return_value
    end # def execute

    protected

    # Handles plot type being changed
    def handle_plot_type_change
      plot_type = @combobox.currentText.downcase
      @editor.dispose
      @editor = Cosmos.require_class(plot_type.capitalize + '_plot_editor').new(self)
      @editor_layout.addWidget(@editor)
    end

  end # class TabbedPlotsPlotEditor

end # module Cosmos
