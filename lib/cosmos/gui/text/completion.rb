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
require 'cosmos/script'

module Cosmos

  class Completion < Qt::Completer
    CMD_KEYWORDS = %w(cmd cmd_no_range_check cmd_no_hazardous_check cmd_no_checks
      cmd_raw cmd_raw_no_range_check cmd_raw_no_hazardous_check cmd_raw_no_checks)
    TLM_KEYWORDS = %w(set_tlm set_tlm_raw
    tlm tlm_raw tlm_formatted tlm_with_units
    limits_enabled? enable_limits disable_limits
    check check_raw check_tolerance check_tolerance_raw
    wait wait_raw wait_tolerance wait_tolerance_raw wait_check wait_check_raw wait_check_tolerance wait_check_tolerance_raw)

    slots 'insertCompletion(const QString&)'

    def initialize(parent)
      # Must be called first
      super(parent)
      # Connect the completion to the passed in widget
      setWidget(parent)
      setCaseSensitivity(Qt::CaseInsensitive)

      @text_widget = parent
      @target = nil
      @command = nil
      connect(self, SIGNAL('activated(const QString&)'), self, SLOT('insertCompletion(const QString&)'))
    end

    def insertCompletion(completion)
      # Delete the characters already entered (the completionPrefix)
      # and then insert the full completion text. This allows the user to enter search text
      # in lower case but it will be completed with upper case text.
      (0...completionPrefix.length).each do
        widget.textCursor.deletePreviousChar
      end
      widget.textCursor.insertText(completion)
      widget.setTextCursor(widget.textCursor)
      # Signal back to the code completion an Enter key so we can continue to process the line
      event = Qt::KeyEvent.new(Qt::Event::KeyPress, Qt::Key_Enter, Qt::NoModifier)
      handle_keypress(event)
      event.dispose
    end

    # Create the popup based on the list of strings
    def create_popup(list)
      cr = widget.cursorRect
      setModel(Qt::StringListModel.new(list, self))
      cr.setWidth(popup.sizeHintForColumn(0) + popup.verticalScrollBar.sizeHint.width())
      complete(cr) # popup it up!
    end

    def handle_tlm(line)
      # Bail if the line is already completed i.e. ends with )
      if line =~ /\"\)/ or line =~ /\)\s*$/ or line =~ /\w\s*\"$/
        popup.close
        return
      end

      # First determine where in the line we are
      tlm_line = line.split(/\"/)[1]
      # If there isn't a first quote i.e. tlm("
      # then we need to handle targets
      if tlm_line.nil?
        handle_targets(line, false)
      else
        # We need a word after the target to have a packet to work with
        num_items = tlm_line.split.length
        if num_items <= 1 and not tlm_line =~ /\w+\s$/
          handle_targets(line, false)
        elsif (num_items <= 1 and tlm_line =~ /\w+\s$/) or
          (num_items == 2 and not tlm_line =~ /\w+\s$/)
          handle_packets(tlm_line)
        elsif (num_items <= 2 and tlm_line =~ /\w+\s$/) or
          (num_items == 3 and not tlm_line =~ /\w+\s+$/)
          handle_items(tlm_line)
        else
          popup.close
        end
      end
    end

    def handle_packets(tlm_line)
      parts = tlm_line.split
      if popup.isVisible and not parts[1].nil?
        setCompletionPrefix(parts[1].upcase)
      else
        target_name = parts[0].strip

        begin
          packets = System.telemetry.packets(target_name)
          packet_names = []
          packets.each {|packet_name, packet| packet_names << "#{packet_name} " unless packet.hidden }
          packet_names.sort!

          # If there is only one packet then just insert the value
          if packet_names.length == 1
            widget.textCursor.insertText(packet_names[0])
            handle_tlm(widget.textCursor.block.text)
          else
            if parts[1].nil?
              setCompletionPrefix("")
            else
              setCompletionPrefix(parts[1].upcase)
            end
            create_list_popup(packet_names)
          end
        rescue
          # Don't do anything
        end
      end
    end

    def handle_items(tlm_line)
      @processing = "TLM_ITEM"
      parts = tlm_line.split
      if popup.isVisible and not parts[2].nil?
        setCompletionPrefix(parts[2].upcase)
      else
        target_name = parts[0].strip
        packet_name = parts[1].strip

        begin
          items = System.telemetry.items(target_name, packet_name)
          item_names = []
          items.each {|item| item_names << "#{item.name}\")"}
          item_names.sort!
          if parts[2].nil?
            setCompletionPrefix("")
          else
            setCompletionPrefix(parts[2].upcase)
          end
          create_list_popup(item_names)
        rescue
          # Don't do anything
        end
      end
    end

    # We need to handle ANY substring of the passed in line: cmd("TARGET CMD with PARAM1 X, PARAM2 Y")
    def handle_cmd(line)
      # Bail if the line is already completed i.e. ends with ")
      if line =~ /\"\)/ or line =~ /\w\"$/
        popup.close
        return
      end

      # First determine where in the line we are
      cmd_line = line.split(/\"/)[1]
      # If there isn't a first quote i.e. cmd("
      # then we need to handle targets
      if cmd_line.nil?
        handle_targets(line, true)
      else
        # We need a word after the target to have a command to work with
        # We also process commands if the line ends with a character followed by a space i.e. "TARGET "
        if cmd_line.split.length <= 1 and not cmd_line =~ /\w+\s$/
          handle_targets(line, true)
        elsif cmd_line.split.length > 1 or cmd_line =~ /\w+\s$/
          # If there is a "with" we handle parameters
          if cmd_line =~ /with\s/
            # If the line already ends in a comma the parameter is complete so don't process it
            if cmd_line =~ /,$/
              popup.close
            else
              handle_parameters(cmd_line, line =~ /cmd_raw/)
            end
          else
            handle_commands(cmd_line)
          end
        else
          popup.close
        end
      end
    end

    def handle_targets(line, use_command_definition = false)
      # Filter the targets if our popup is already up and there is some text to filter by
      if popup.isVisible and line.split('(').length > 1
        setCompletionPrefix(line.split('(')[-1].to_s.upcase)
      else
        if use_command_definition
          target_names = System.commands.target_names
        else
          target_names = System.telemetry.target_names
        end
        target_names_to_delete = []
        target_names.each do |target_name|
          found_non_hidden = false
          begin
            if use_command_definition
              packets = System.commands.packets(target_name)
            else
              packets = System.telemetry.packets(target_name)
            end
            packets.each do |packet_name, packet|
              found_non_hidden = true unless packet.hidden
            end
          rescue
            # Don't do anything
          end
          target_names_to_delete << target_name unless found_non_hidden
        end
        target_names_to_delete.each do |target_name|
          target_names.delete(target_name)
        end

        len = target_names.length
        len.times do |i|
          target_names[i] = "\"#{target_names[i]} "
        end
        target_names.sort!
        if line.split('(').length > 1
          setCompletionPrefix(line.split('(')[-1].to_s.upcase)
        else
          setCompletionPrefix("")
        end
        create_list_popup(target_names)
      end
    end

    def handle_commands(cmd_line)
      parts = cmd_line.split
      if popup.isVisible and not parts[1].nil?
        # Filter on the parts after the first space
        setCompletionPrefix(cmd_line[/\s(.*)/,1].to_s.upcase)
      else
        target_name = parts[0].strip.upcase

        begin
          commands = System.commands.packets(target_name)
          command_strings = []
          commands.each do |command_name, command|
            next if command.hidden
            target = System.targets[target_name]
            params = System.commands.params(target_name, command_name)
            no_params = true
            command_string = nil
            params.each do |param|
              if not target.ignored_parameters.include?(param.name)
                command_string = "#{command.packet_name} with "
                no_params = false
                break
              end
            end
            command_string = "#{command.packet_name}\")" if no_params
            command_strings << command_string
          end
          command_strings.sort!

          # Filter on the parts joined back together to include the potential for "with" after the command
          if parts[1].nil?
            setCompletionPrefix("")
          else
            setCompletionPrefix(cmd_line[/\s(.*)/,1].to_s.upcase)
          end
          create_list_popup(command_strings)
        rescue
          # Don't do anything
        end
      end
    end

    def handle_parameters(cmd_line, raw = false)
      if popup.isVisible and not cmd_line.split("with")[1].nil?
        parameter = cmd_line.split("with")[1].split(',')[-1].lstrip
        setCompletionPrefix(parameter.upcase)
      else
        begin
          parts = cmd_line.split
          target_name = parts[0].strip.upcase
          command_name = parts[1].strip

          target = System.targets[target_name]
          params = System.commands.params(target_name, command_name)
          parameters = []
          params.each do |param|
            if not target.ignored_parameters.include?(param.name)
              if param.states.nil? or param.states.empty? or raw
                param.default = "'X' " if param.default.is_a? String and param.default.strip.length == 0
                parameters << (param.name + ' ' + param.default.to_s + ', ')
              else
                states = param.states.keys
                states.sort!
                states.each do |state|
                  parameters << (param.name + ' ' + state + ', ')
                end
              end
            end
          end
          parameters.sort!

          # If there is only one parameter then just insert the value
          if parameters.length == 1
            parameters[0] = parameters[0][0..-3] + '")'
            widget.textCursor.insertText(parameters[0])
          else
            unless cmd_line.split("with")[1].nil?
              param = cmd_line.split("with")[1].split(',')[-1].lstrip
              setCompletionPrefix(param.upcase)
            else
              setCompletionPrefix("")
            end
            create_list_popup(parameters)
          end
        rescue
          # Don't do anything
        end
      end
    end

    #Creates a Popup box to help with code completion
    def create_list_popup(list_items)
      return if list_items.nil? or list_items.empty?
      create_popup(list_items)
    end

    # Called by script_runner on SEL_KEYRELEASE
    def handle_keypress(event)
      current_line = widget.textCursor.block.text

      if event.key == Qt::Key_Escape
        popup.close
        # Figure out if the last bit of text has a comma in it, indicating the last entry was a parameter
        # Since the user just hit escape we want to strip the command to make the last parameter the final parameter
        if current_line.rstrip[-1,1] == ','
          widget.textCursor.deletePreviousChar
          widget.textCursor.deletePreviousChar
          widget.textCursor.insertText('")')
        end
        return
      end

      if event.key == Qt::Key_Backspace
        popup.close
        return
      end

      # Only process if we have an open paren which indicates a function
      if current_line =~ /\(/
        split_on_paren = current_line.split('(')[0]
        if split_on_paren
          if CMD_KEYWORDS.include? split_on_paren.split[-1]
            @processing = "CMD"
            handle_cmd(current_line)
          elsif TLM_KEYWORDS.include? split_on_paren.split[-1]
            @processing = "TLM"
            handle_tlm(current_line)
          else
            popup.close
          end
        end
      end

      # Sometimes the popup clears all the values unexpectedly.
      # This also destroys the model which breaks the second to last line of code.
      # If this happens just reprocess the line to cause a new popup to display.
      if model.nil?
        popup.close
        handle_cmd(current_line) if @processing == "CMD"
        handle_tlm(current_line) if @processing == "TLM"
      end

      # Ensure the top item is always selected as a visual cue to the user
      popup.setCurrentIndex(model.index(0,0)) if popup.isVisible
      setCurrentRow(0) if popup.isVisible
    end
  end

end # module Cosmos
