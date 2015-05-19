# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/script/script'

$cmd_tlm_gui_window = nil

class Qt::MessageBox
  def exec(*args)
    Cosmos.play_wav_file('message.wav') if Cosmos::System.sound
    method_missing(:exec, *args)
  end
  def self.critical(parent, title, text,
                    buttons = Qt::MessageBox::Ok,
                    defaultButton = Qt::MessageBox::NoButton)
    # Windows overrides critical dialogs with its own alert sound
    Cosmos.play_wav_file('critical.wav') if Cosmos::System.sound
    super(parent,title,text,buttons,defaultButton)
  end
  def self.information(parent, title, text,
                       buttons = Qt::MessageBox::Ok,
                       defaultButton = Qt::MessageBox::NoButton)
    Cosmos.play_wav_file('information.wav') if Cosmos::System.sound
    super(parent,title,text,buttons,defaultButton)
  end
  def self.question(parent, title, text,
                    buttons = Qt::MessageBox::Ok,
                    defaultButton = Qt::MessageBox::NoButton)
    Cosmos.play_wav_file('question.wav') if Cosmos::System.sound
    super(parent,title,text,buttons,defaultButton)
  end
  def self.warning(parent, title, text,
                   buttons = Qt::MessageBox::Ok,
                   defaultButton = Qt::MessageBox::NoButton)
    # Windows overrides warning dialogs with its own alert sound
    Cosmos.play_wav_file('warning.wav') if Cosmos::System.sound
    super(parent,title,text,buttons,defaultButton)
  end
end

class Qt::InputDialog
  def self.getText(parent, title, label,
                   mode = Qt::LineEdit::Normal,
                   text = '', ok = 0, flags = 0,
                   inputMethodHints = Qt::ImhNone)
    Cosmos.play_wav_file('input.wav') if Cosmos::System.sound
    super(parent, title, label, mode, text, ok, flags, inputMethodHints)
  end
end

module Cosmos

  # Cosmos script changes to handle hazardous commands and prompts
  old_verbose = $VERBOSE; $VERBOSE = nil
  module Script
    private

    @@qt_boolean = Qt::Boolean.new

    def ask_string(question, blank_or_default = false, password = false)
      answer = ''
      if blank_or_default != true && blank_or_default != false
        default = blank_or_default.to_s
        allow_blank = false
      else
        default = ''
        allow_blank = blank_or_default
      end
      loop do
        canceled = false
        Qt.execute_in_main_thread(true, 0.05) do
          window = nil
          window = get_cmd_tlm_gui_window() if get_cmd_tlm_gui_window()
          # Create a special mutable QT variable that can return what button was pressed
          if password
            answer = Qt::InputDialog::getText(window, "Ask", question, Qt::LineEdit::Password, default, @@qt_boolean)
          else
            answer = Qt::InputDialog::getText(window, "Ask", question, Qt::LineEdit::Normal, default, @@qt_boolean)
          end
          # @@qt_boolean is nil if the user presses cancel in the dialog
          # Note that it is not actually nil, just the nil? method returns true
          canceled = @@qt_boolean.nil?
        end
        if canceled
          Logger.warn "User pressed 'Cancel' for '#{question}'"
          prompt_for_script_abort()
        end
        # If the answer wasn't nil and contains a value we break
        break if allow_blank or (not answer.nil? and answer.strip.length != 0)
      end

      if password
        Logger.info "User responded to '#{question}'"
      else
        Logger.info "User entered '#{answer}' for '#{question}'"
      end
      return answer.to_s
    end

    def prompt_dialog_box(title, message)
      result = nil
      Qt.execute_in_main_thread(true, 0.05) do
        window = nil
        window = get_cmd_tlm_gui_window() if get_cmd_tlm_gui_window()
        msg = Qt::MessageBox.new(window)
        msg.setIcon(Qt::MessageBox::Warning)
        msg.setText(message)
        msg.setWindowTitle(title)
        msg.setStandardButtons(Qt::MessageBox::Yes | Qt::MessageBox::No)
        msg.setDefaultButton(Qt::MessageBox::Yes)
        case msg.exec()
        when Qt::MessageBox::Yes
          Logger.info "User pressed 'Yes' for '#{message}'"
          result = true
        when Qt::MessageBox::No
          Logger.info "User pressed 'No' for '#{message}'"
          result = false
        end
        msg.dispose
      end
      return result
    end

    def prompt_for_hazardous(target_name, cmd_name, hazardous_description)
      message = "Warning: Command #{target_name} #{cmd_name} is Hazardous. "
      message << "\n#{hazardous_description}\n" if hazardous_description
      message << "Send?"
      return prompt_dialog_box('Hazardous Command', message)
    end

    def prompt_for_script_abort
      return true # Aborted - Don't retry
    end

    def prompt_to_continue(string)
      loop do
        stop = false
        Qt.execute_in_main_thread(true, 0.05) do
          window = nil
          window = get_cmd_tlm_gui_window() if get_cmd_tlm_gui_window()
          result = Qt::MessageBox::question(window,
                                            "COSMOS",
                                            "#{string}\n\nOK to Continue?",
                                            Qt::MessageBox::Ok | Qt::MessageBox::Cancel,
                                            Qt::MessageBox::Ok)
          if result == Qt::MessageBox::Ok
            Logger.info "User pressed 'Ok' for '#{string}'"
          else
            stop = true
            Logger.warn "User pressed 'Cancel' for '#{string}'"
          end
        end
        if stop
          prompt_for_script_abort()
        else
          break
        end
      end
    end

    def prompt_message_box(string, buttons)
      loop do
        answer_text = nil
        Qt.execute_in_main_thread(true, 0.05) do
          window = nil
          window = get_cmd_tlm_gui_window() if get_cmd_tlm_gui_window()
          msg = Qt::MessageBox.new(window)

          msg.setText(string)
          msg.setWindowTitle("Message Box")
          buttons.each {|text| msg.addButton(text, Qt::MessageBox::AcceptRole)}
          msg.addButton("Cancel", Qt::MessageBox::RejectRole)
          msg.exec()
          if msg.clickedButton.text == "Cancel"
            Logger.warn "User pressed 'Cancel' for '#{string}'"
          else
            Logger.info "User pressed '#{msg.clickedButton.text}' for '#{string}'"
          end
          answer_text = msg.clickedButton.text
          msg.dispose
        end
        if answer_text == "Cancel"
          prompt_for_script_abort()
        else
          return answer_text
        end
      end
    end

    def get_scriptrunner_log_message(title_text = "Script Message Log Text Entry", prompt_text = 'Enter text to log to the script message log')
      answer = ""
      canceled = false
      Qt.execute_in_main_thread(true, 0.05) do
        window = nil
        window = get_cmd_tlm_gui_window() if get_cmd_tlm_gui_window()
        # Create a special mutable QT variable that can return what button was pressed
        answer = Qt::InputDialog::getText(window, title_text, prompt_text, Qt::LineEdit::Normal, "", @@qt_boolean)
        # @@qt_boolean is nil if the user presses cancel in the dialog
        # Note that it is not actually nil, just the nil? method returns true
        canceled = @@qt_boolean.nil?
      end
      if canceled
        return nil
      else
        return answer.to_s
      end
    end

    def set_cmd_tlm_gui_window (window)
      $cmd_tlm_gui_window = window
    end

    def get_cmd_tlm_gui_window
      $cmd_tlm_gui_window
    end

  end # module Script
  $VERBOSE = old_verbose

end # module Cosmos
