# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos
  class FullTextSearchLineEdit < Qt::LineEdit

    attr_accessor :completion_list
    attr_accessor :callback

    def initialize(parent)
      super(parent)
      @listView = Qt::ListWidget.new(parent)
      @listView.setWindowFlags(0xc | 0x1) # Qt::ToolTip
      @completion_list = []
      @filtered_list = []
      @callback = nil
      connect(self, SIGNAL("textChanged(const QString &)")) do |text|
        handleTextChanged()
      end
      connect(@listView, SIGNAL("itemClicked(QListWidgetItem*)")) do |item|
        text = item.text
        setText(text)
        @callback.call(text) if @callback
        @listView.hide
      end
    end

    def focusOutEvent(e)
      Qt.execute_in_main_thread(false, 0.001, true) do
        unless @listView.hasFocus
          @listView.hide
        end
      end
      super(e)
    end

    def keyPressEvent(e)
      key = e.key
      if !@listView.isHidden
        count = @filtered_list.length
        row = @listView.currentRow

        # Move through list
        if (key == Qt::Key_Down || key == Qt::Key_Up)
          case(key)
          when Qt::Key_Down
            row += 1
            row = 0 if row >= count
          when Qt::Key_Up
            row -= 1
            row = count - 1 if row < 0
          end

          if @listView.isEnabled
            @listView.setCurrentRow(row)
          end

        # Accept choice
        elsif ((Qt::Key_Enter == key || Qt::Key_Return == key) && @listView.isEnabled)
          if row >= 0
            text = @listView.item(row).text
            setText(text)
            @listView.hide
            handleTextChanged()
            @callback.call(text) if @callback
            @listView.hide
          else
            super(e)
          end

        # Cancel
        elsif Qt::Key_Escape == key
          @listView.hide

        # More data entry
        else
          @listView.hide
          super(e)
        end

      else
        # Up/down potentially after cancel
        if (key == Qt::Key_Down || key == Qt::Key_Up)
          handleTextChanged()

          if !@listView.isHidden
            case(key)
            when Qt::Key_Down
              row = 0
            when Qt::Key_Up
              row = @filtered_list.length - 1
            end

            if @listView.isEnabled
              @listView.setCurrentRow(row)
            end
          end

        # More data entry
        else
          if ((Qt::Key_Enter == key || Qt::Key_Return == key))
            @callback.call(self.text) if @callback
            @listView.hide
          end
          super(e)
        end
      end
    end

    def handleTextChanged
      text = self.text
      if text.empty?
        @listView.hide
        return
      end

      updateFilteredList(text)

      if @filtered_list.length == 0 or (@filtered_list.length ==1 and text == @filtered_list[0])
        @listView.hide
        return
      end

      maxVisibleRows = 10
      p = Qt::Point.new(0, height())
      x = mapToGlobal(p).x
      y = mapToGlobal(p).y + 1
      p.dispose
      @listView.move(x, y)
      @listView.setMinimumWidth(width())
      @listView.setMaximumWidth(width())
      if @filtered_list.length > maxVisibleRows
        @listView.setFixedHeight(maxVisibleRows * (@listView.fontMetrics.height + 2) + 2)
      else
        @listView.setFixedHeight((@filtered_list.length + 1) * (@listView.fontMetrics.height + 2) + 2)
      end

      @listView.show
      @listView.raise
    end

    def updateFilteredList(text)
      @filtered_list = []
      regex = Regexp.new(Regexp.quote(text), Regexp::IGNORECASE)
      @completion_list.each do |string|
        @filtered_list << string if string =~ regex
      end
      @listView.clear
      @listView.addItems(@filtered_list)
      @listView.setCurrentRow(0) if @filtered_list.length > 0
    end

  end # class FullTextSearchLineEdit
end # module Cosmos
