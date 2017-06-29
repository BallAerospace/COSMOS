# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/cmd_sequence/sequence_item'

module Cosmos
  # Widget which displays a list of SequenceItems
  class SequenceList < Qt::Widget
    include Enumerable
    # Emit modified whenever any of the underlying SequenceItems change
    signals 'modified()'

    # Create the SequenceList
    def initialize
      super()
      @modified = false
      layout = Qt::VBoxLayout.new()
      layout.setContentsMargins(0, 0, 0, 0)
      layout.setSpacing(0)
      setLayout(layout)
      setSizePolicy(1, 0)
      layout.addWidget(create_header())
    end

    # Opens a sequence definition file and populates the sequence.
    # Exceptions are re-raised with filename and line number information
    # and must be handled by the higher level application.
    #
    # @param filename [String] File containing a sequence definition
    def open(filename)
      clear()

      parser = ConfigParser.new("http://cosmosrb.com/docs/tools/#command-sequence-configuration")
      parser.parse_file(filename) do |keyword, params|
        case keyword
        when 'COMMAND'
          usage = "#{keyword} <Delay Time> <Command>"
          parser.verify_num_parameters(2, 2, usage)
          begin
            item = SequenceItem.parse(params[0], params[1])
            # Connect the SequenceItems modified signal to propagate it
            # forward by emitting our own modified signal
            item.connect(SIGNAL("modified()")) do
              @modified = true
              emit modified()
            end
            layout.addWidget(item)
          rescue => error
            Kernel.raise parser.error("#{usage} passed '#{params[0]} #{params[1]}'\n#{error.message}")
          end
        else
          Kernel.raise parser.error("Unknown keyword '#{keyword}'.") if keyword
        end
      end
      @modified = false # Initially we're not modified
    end

    # Add a new SequenceItem to the list.
    # @param command [Packet] Command packet to base the SequenceItem on
    # @return [SequenceItem] The item added
    def add(command)
      @modified = true
      item = SequenceItem.new(command)
      # Connect the SequenceItems modified signal to propagate it
      # forward by emitting our own modified signal
      item.connect(SIGNAL("modified()")) do
        @modified = true
        emit modified()
      end
      layout.addWidget(item)
      emit modified()
      item
    end

    # Clear the list by removing all SequenceItems and disposing them
    def clear
      @modified = false
      (1...layout.count).each do |index|
        item = layout.takeAt(1)
        item.widget.dispose
      end
      emit modified()
    end

    # @return [Boolean] Whether the list is modified
    def modified?
      @modified
    end

    # Yield each SequenceItem to enable the included Enumerable module
    def each
      total_items = 1
      Qt.execute_in_main_thread { total_items = layout.count }
      (1...total_items).each do |index|
        item = nil
        Qt.execute_in_main_thread { item = layout.itemAt(index).widget }
        yield item
      end
    end

    # Calls save on all individual SequenceItems and writes out the result
    # to the given filename. Exceptions must be handled by the higher level
    # application.
    # @param filename [String] Filename to open and write the sequence
    def save(filename)
      @modified = false
      File.open(filename, "w") do |file|
        # Each SequenceItem's save method returns the save string
        file.write(collect {|item| item.save }.join("\n"))
        file.write("\n") # final newline
      end
    end

    protected

    # Create a header item in the SequenceList to describe the SequenceItems
    def create_header
      header = Qt::Widget.new
      header_layout = Qt::HBoxLayout.new
      header_layout.setContentsMargins(5, 5, 5, 5)
      header.setLayout(header_layout)
      time = Qt::Label.new("Time (Delay or Absolute)")
      time.setFixedWidth(130)
      header_layout.addWidget(time)
      command = Qt::Label.new("Command")
      header_layout.addWidget(command)
      header_layout.addStretch()
      header
    end

    # TODO: The following are various methods that could be used in future
    # drag and drop support.
    #
    # def swap(index1, index2)
    #   STDOUT.puts "swap:#{index1}, #{index2} count:#{layout.count}"
    #  widget1 = layout.takeAt(index1).widget
    #  index1 = widget1.index
    #  widget2 = layout.takeAt(index2).widget
    #  index2 = widget2.index
    #  widget2.index = index1
    #  widget1.index = index2
    #  layout.insertWidget(index1, widget2)
    #  layout.insertWidget(index2, widget1)
    # end
    #
    # def mousePressEvent(event)
    #   super(event)
    #   if event.button == Qt::LeftButton
    #     @dragStartPosition = event.pos
    #   end
    #   @expanded = !@expanded
    #   if @expanded
    #     @parameters.show
    #   else
    #     @parameters.hide
    #   end
    # end
    #
    # def mouseMoveEvent(event)
    #  super(event)
    #  return unless (event.buttons & Qt::LeftButton)
    #  return if (event.pos - @dragStartPosition).manhattanLength() < Qt::Application::startDragDistance()
    #
    #  mime = Qt::MimeData.new()
    #  mime.setText(@index.to_s)
    #  drag = Qt::Drag.new(self)
    #  drag.setMimeData(mime)
    #  drop = drag.exec(Qt::MoveAction)
    # end
    #
    # def dragEnterEvent(event)
    #  if event.mimeData.text != @text.to_s
    #    event.acceptProposedAction
    #    setStyleSheet("background-color:grey")
    #  end
    # end
    #
    # def dragLeaveEvent(event)
    #  setStyleSheet("background-color:")
    # end
    #
    # def dropEvent(event)
    #  setStyleSheet("background-color:white")
    # end
  end
end
