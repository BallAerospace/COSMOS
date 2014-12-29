# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/qt'

module Cosmos

  class LauncherTool < Qt::Object
    slots 'button_clicked()'

    def initialize(parent, button_text, shell_command, capture_io, variable_parameters)
      super(parent)
      @button_text = button_text
      @shell_command = shell_command
      @capture_io = capture_io
      @variable_parameters = variable_parameters
    end

    def button_clicked
      if @variable_parameters
        parameters = parameters_dialog()
        if parameters
          if @capture_io
            Cosmos.run_process_check_output(@shell_command + ' ' + parameters)
          else
            Cosmos.run_process(@shell_command + ' ' + parameters)
          end
        end
      else
        if @capture_io
          Cosmos.run_process_check_output(@shell_command)
        else
          Cosmos.run_process(@shell_command)
        end
      end
    end

    def parameters_dialog
      dialog = Qt::Dialog.new(self.parent)
      dialog.window_title = "#{@button_text} Options"
      layout = Qt::VBoxLayout.new
      dialog.layout = layout

      widgets = []
      @variable_parameters.each do |parameter_name, parameter_value|
        hlayout = Qt::HBoxLayout.new
        hlayout.addWidget(Qt::Label.new(parameter_name))
        line_edit = Qt::LineEdit.new()
        line_edit.setText(parameter_value)
        hlayout.addWidget(line_edit)
        widgets << line_edit
        layout.addLayout(hlayout)
      end

      ok_button = Qt::PushButton.new('Ok')
      connect(ok_button, SIGNAL('clicked()'), dialog, SLOT('accept()'))
      cancel_button = Qt::PushButton.new('Cancel')
      connect(cancel_button, SIGNAL('clicked()'), dialog, SLOT('reject()'))

      hlayout = Qt::HBoxLayout.new
      hlayout.addWidget(ok_button, 0, Qt::AlignLeft)
      hlayout.addWidget(cancel_button, 0, Qt::AlignRight)
      layout.addLayout(hlayout)

      dialog.resize(400, 0)
      cursor_pos = Qt::Cursor.pos
      x_pos = cursor_pos.x - 200
      y_pos = cursor_pos.y - 50
      if x_pos < 0
        x_pos = 0
      elsif x_pos > (Qt::Application.desktop.width - dialog.frameGeometry.width)
        x_pos = Qt::Application.desktop.width - dialog.frameGeometry.width
      end
      dialog.move(x_pos, y_pos)

      result = dialog.exec
      if result == Qt::Dialog::Accepted
        parameters = ''
        index = 0
        @variable_parameters.each do |parameter_name, parameter_value|
          parameters << parameter_name
          parameters << ' '
          parameters << widgets[index].text
          parameters << ' '
          index += 1
        end
        dialog.dispose
        return parameters
      else
        dialog.dispose
        return nil
      end
    end
  end

end
