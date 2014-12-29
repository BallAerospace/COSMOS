# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the ExceptionDialog class.   This class
# is used to display an exception window

require 'cosmos'
require 'cosmos/gui/qt'

module Cosmos

  class ExceptionDialog
    @@mutex = Mutex.new

    def initialize(parent, exception, title = 'COSMOS Exception', exit_afterwards = true, log_exception = true, log_file = nil)
      if @@mutex.try_lock
        unless exception.class == SystemExit or exception.class == Interrupt
          # ConfigParser::Errors are configuration user errors. We don't want to clutter
          # up list of real exceptions with user configuration errors.
          # Same goes for FatalErrors
          unless exception.class == ConfigParser::Error || exception.class == FatalError
            log_file = Cosmos.write_exception_file(exception) if log_exception
          end

          if Qt::CoreApplication.instance
            msg = Qt::MessageBox.new(parent)
            msg.setWindowTitle(title)
            msg.setTextFormat(Qt::RichText)
            msg.setIcon(Qt::MessageBox::Critical)
            case exception
            # ConfigParser::Errors are a special case generated with a known format
            # by the ConfigParser
            when ConfigParser::Error
              # Substitute the html tags '<' and '>' and then replace newlines with html breaks
              usage = exception.usage.gsub("<","&#060;").gsub(">","&#062;").gsub("\n","<br/>")
              message = exception.message.gsub("<","&#060;").gsub(">","&#062;").gsub("\n","<br/>")
              line = exception.keyword + ' ' + exception.parameters.join(' ').gsub("<","&#060;").gsub(">","&#062;").gsub("\n","<br/>")
              text = "Error in #{exception.filename}<br/><br/>Line #{exception.line_number}: #{line}<br/><br/>#{message}<br/><br/>#{usage}"
              unless exception.url.nil?
                text << "<br/><br/>For more information see <a href='#{exception.url}'>#{exception.url}</a>."
              end
              msg.setText(text)
            # FatalErrors are errors explicitly raised when a known fatal issue
            # occurs. Since it is a known issue we don't put up the full error
            # dialog.
            when FatalError
              msg.setText("Error: #{exception.message.gsub("\n","<br/>")}")
            else
              file_contents = ""
              # First read the log_file we wrote out to the logs directory
              # Change newlines to %0A for Outlook and remove all quotes to avoid breaking the link
              begin
                message = exception.message.gsub("\n","<br/>")
                file_contents = File.read(log_file).gsub("\n","%0A").gsub("'","").gsub("\"","") if log_file
              rescue
              end
              text = "The following error occurred:<br/>#{message}"
              text += "<br/><br/>Please contact your local COSMOS expert.<br/><br/>This error has been logged:<br/>#{log_file}<br/><br/> <a href='mailto:rmelton@ball.com;jmthomas@ball.com?subject=COSMOS exception&body=#{file_contents}'>Click here</a> to email this log to the COSMOS developers." if log_file
              msg.setText(text)
            end
            if log_file
              open_button = Qt::PushButton.new("Open Exception Log in Text Editor")
              open_button.connect(SIGNAL('clicked()')) do
                Cosmos.open_in_text_editor(log_file)
                sleep(2)
              end
              msg.addButton(open_button, Qt::MessageBox::ResetRole)
            end
            close_button = Qt::PushButton.new("Close")
            msg.addButton(close_button, Qt::MessageBox::ActionRole)
            msg.raise
            msg.exec
            msg.dispose
          end # if Qt::CoreApplication.instance
        end #  unless exception.class == SystemExit or exception.class == Interrupt
        @@mutex.unlock
        if exit_afterwards
          Qt::CoreApplication.instance.exit(1) if Qt::CoreApplication.instance
          exit 1 # incase CoreApplication doesn't exit yet or didn't complete the exit
        end
      end # if @@mutex.try_lock
    end # def initialize

    def self.dialog_open?
      @@mutex.locked?
    end

  end # class ExceptionDialog

end # module Cosmos
