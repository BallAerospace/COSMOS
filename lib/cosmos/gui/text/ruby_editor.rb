# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/script'
require 'cosmos/gui/qt'
require 'cosmos/gui/text/completion_text_edit'

module Cosmos

  class RubyEditor < CompletionTextEdit
    # private slot used to connect to the blockCountChanged signal
    slots 'line_count_changed(int)'
    # private slot used to connect to the updateRequest signal
    slots 'update_line_number_area(const QRect &, int)'

    signals 'breakpoint_set(int)'
    signals 'breakpoint_cleared(int)'
    signals 'breakpoints_cleared()'
    signals 'font_changed(const QFont &)'

    attr_accessor :enable_breakpoints
    attr_accessor :filename

    # This works but slows down the GUI significantly when
    # pasting a large (10k line) block of code into the editor
    class RubySyntax < Qt::SyntaxHighlighter
      # Ruby keywords - http://www.ruby-doc.org/docs/keywords/1.9/
      # Also include some common methods that are typically called by
      # themselves like puts, print, sleep
      RUBY_KEYWORDS = %w(BEGIN END __ENCODING__ __END__ __FILE__ __LINE__ \
                         alias and begin break case class def defined? do \
                         else elsif end ensure false for if in module \
                         next nil not or raise redo rescue retry return \
                         self super then true undef unless until when while yield \
                         puts print sleep) # common stand alone methods

      def self.create_format(color = Cosmos::BLACK, style='')
        color = Cosmos::getColor(color)
        brush = Cosmos::getBrush(color)

        format = Qt::TextCharFormat.new
        format.setForeground(brush)
        if style == 'bold'
          format.setFontWeight(Qt::Font::Bold)
        end
        if style == 'italic'
          format.setFontItalic(true)
        end
        format
      end

      # Syntax styles - refer to the ruby.properties in Scite
      STYLES = {
        'normal' => create_format('black'),
        'ruby_keyword' => create_format('darkBlue','bold'),
        'cosmos_keyword' => create_format('blue','bold'),
        'operator' => create_format('red'),
        'brace' => create_format('black','bold'),
        'class' => create_format('blue', 'bold'),
        'method' => create_format(Cosmos::getColor(0, 127, 127), 'bold'),
        'string' => create_format(Cosmos::getColor(127, 0, 127)),
        'symbol' => create_format(Cosmos::getColor(192,160,48)),
        'comment' => create_format('green'),
      }

      # Ruby braces
      BRACES = ['\{', '\}', '\(', '\)', '\[', '\]','\|']

      RULES = []
      RUBY_KEYWORDS.each do |w|
        RULES << ['\b'+w+'\b', STYLES['ruby_keyword']]
      end
      Script.private_instance_methods.each do |w|
        RULES << ['\b'+w.to_s+'\b', STYLES['cosmos_keyword']]
      end
      BRACES.each do |b|
        RULES << ["#{b}", STYLES['brace']]
      end
      RULES.concat([
          # 'def' followed by an identifier
          ['\bdef\b\s*(\w+)', STYLES['method']],
          # 'class' followed by an identifier
          ['\bclass\b\s*(\w+)', STYLES['class']],
          # Ruby symbol
          [':\b\w+', STYLES['symbol']],
          # Ruby namespace operator
          ['\b\w+(::\b\w+)+', STYLES['class']],
          # Ruby global
          ['\\$\b\w+', STYLES['string']],
          # Regex, possibly containing escape sequences
          ["/.*/", STYLES['string']],
          # Double-quoted string, possibly containing escape sequences
          ['"(?:[^"\\\\]|\\\\.)*"', STYLES['string']],
          # Match interpolated strings "blah #{code} blah"
          # This comes before single-quote and back-tick because
          # those strings should not interpolate variables
          ['(\#\\{)[^\\}]*\\}', STYLES['brace']],
          ['\#\\{[^\\}]*(\\})', STYLES['brace']],
          ['\#\\{([^\\}]*)\\}', STYLES['normal']],
          # Single-quoted string, possibly containing escape sequences
          ["'[^'\\\\]*(?:\\.[^'\\\\]*)*'", STYLES['string']],
          # Back-tick string, possibly containing escape sequences
          ["`[^`\\\\]*(\\.[^`\\\\]*)*`", STYLES['string']],
          # Double quoted string | single quoted string | comment
          # We don't want the first two but we want the last
          ["\"[^\"]*\"|\'[^\']*\'|(#.*)", STYLES['comment']],
      ])

      # Build a RegExp for each pattern
      RULES_INFO = []
      RULES.each do |pat, fmt|
        RULES_INFO << [Regexp.new(pat), fmt]
      end

      def highlightBlock(text)
        # Do other syntax formatting
        RULES_INFO.each do |expression, format|
          match = text.scan(expression).flatten.compact
          next unless match && !match.empty?
          i = 0 # initial string match offset
          match.each do |part|
            # Index the match part starting at the offset
            index = text.index(part, i)
            self.setFormat(index, part.length, format)
            # Increment the index so we can match the same string
            # in two different locations in the text, e.g. "#{x} #{y}"
            i = index + part.length
          end
        end
      end
    end

    class LineNumberArea < Qt::Widget
      def initialize(editor)
        super(editor)
        @codeEditor = editor
        self
      end

      def paintEvent(event)
        @codeEditor.line_number_area_paint_event(event)
      end
    end

    CHAR_57 = Qt::Char.new(57)
    BREAKPOINT_SET = 1
    BREAKPOINT_CLEAR = -1
    MINIMUM_POINT_SIZE = 4

    def initialize(parent, font = Cosmos.get_default_font)
      super(parent)
      setFont(font)
      @fontMetrics = Cosmos.getFontMetrics(font)

      # This is needed so text searching highlights correctly
      setStyleSheet("selection-background-color: lightblue; selection-color: black;")

      @breakpoints = []
      @enable_breakpoints = false

      # RubySyntax works but slows down the GUI significantly when
      # pasting a large (10k line) block of code into the editor
      @syntax = RubySyntax.new(document())
      @lineNumberArea = LineNumberArea.new(self)

      connect(self, SIGNAL('blockCountChanged(int)'), self, SLOT('line_count_changed(int)'))
      connect(self, SIGNAL('updateRequest(const QRect &, int)'), self, SLOT('update_line_number_area(const QRect &, int)'))

      line_count_changed(-1)
    end

    def wheelEvent(event)
      if event.modifiers() == Qt::ControlModifier && event.delta > 0
        event.setAccepted(true)
        zoom_in()
      elsif event.modifiers() == Qt::ControlModifier && event.delta < 0
        event.setAccepted(true)
        zoom_out()
      else
        super(event)
      end
    end

    def dispose
      super()
      @syntax.dispose
      @lineNumberArea.dispose
    end

    def context_menu(point)
      menu = createStandardContextMenu()
      return menu unless @enable_breakpoints

      menu.addSeparator()
      menu.addAction(create_add_breakpoint_action(point))
      menu.addAction(create_clear_breakpoint_action(point))
      menu.addAction(create_clear_all_breakpoints_action())
      menu
    end

    def add_breakpoint(line)
      @breakpoints << line
      block = document.findBlockByNumber(line-1)
      block.setUserState(BREAKPOINT_SET)
      block.dispose
      block = nil
      @lineNumberArea.repaint
    end

    def clear_breakpoint(line)
      @breakpoints.delete(line)
      block = document.findBlockByNumber(line-1)
      block.setUserState(BREAKPOINT_CLEAR)
      block.dispose
      block = nil
      @lineNumberArea.repaint
    end

    def clear_breakpoints
      @breakpoints = []
      block = document.firstBlock()
      while (block.isValid())
        block.setUserState(BREAKPOINT_CLEAR)
        next_block = block.next()
        block.dispose
        block = next_block
      end
      block.dispose
      block = nil
      @lineNumberArea.repaint
    end

    def update_breakpoints
      return if @breakpoints.empty?

      breakpoints = []
      block = document.firstBlock()
      while (block.isValid())
        if block.userState() == BREAKPOINT_SET
          line = block.firstLineNumber() + 1
          breakpoints << line
        end
        next_block = block.next()
        block.dispose
        block = next_block
      end
      block.dispose
      block = nil

      # Only emit signals if the breakpoints have changed.
      if @breakpoints.sort != breakpoints.sort
        emit breakpoints_cleared
        breakpoints.each {|line| emit breakpoint_set(line)}
        @breakpoints = breakpoints
      end
    end

    def comment_or_uncomment_lines
      cursor = textCursor
      no_selection = cursor.hasSelection ? false : true

      # Start the edit block so this can be all undone with a single undo step
      cursor.beginEditBlock
      selection_end = cursor.selectionEnd
      # Initially place the cursor at the beginning of the selection
      # If nothing is selected this will just put the cursor at the beginning
      # of the current line
      cursor.setPosition(textCursor.selectionStart)
      cursor.movePosition(Qt::TextCursor::StartOfLine)
      result = true
      while (cursor.position < selection_end && result == true) || (no_selection)
        # Check for a special comment
        if cursor.block.text =~ /^\S*#~/
          cursor.deleteChar
          cursor.deleteChar
          # Since we deleted two spaces we need to move the end position by two
          selection_end -= 2
        else
          cursor.insertText("#~")
          # Since we deleted two spaces we need to move the end position by two
          selection_end += 2
        end
        # Move the cursor to the beginning of the next line
        cursor.movePosition(Qt::TextCursor::StartOfLine)
        result = cursor.movePosition(Qt::TextCursor::Down)
        # If nothing was selected then its a single line so break
        break if no_selection
      end
      cursor.endEditBlock
    end

    def zoom_in
      font = Cosmos.getFont(font().family, font().pointSize + 1)
      setFont(font)
      @fontMetrics = Cosmos.getFontMetrics(font)
      emit font_changed(font)
    end

    def zoom_out
      return if font().pointSize <= MINIMUM_POINT_SIZE
      font = Cosmos.getFont(font().family, font().pointSize - 1)
      setFont(font)
      @fontMetrics = Cosmos.getFontMetrics(font)
      emit font_changed(font)
    end

    def zoom_default
      font = Cosmos.get_default_font
      setFont(font)
      @fontMetrics = Cosmos.getFontMetrics(font)
      # Force a repaint of the number area by doing a small scroll
      verticalScrollBar.setValue(verticalScrollBar.minimum+1)
      verticalScrollBar.setValue(verticalScrollBar.minimum)
      emit font_changed(font)
    end

    def resizeEvent(e)
      super(e)
      cr = self.contentsRect()
      rect = Qt::Rect.new(cr.left(),
        cr.top(),
        line_number_area_width(),
        cr.height())
      @lineNumberArea.setGeometry(rect)
      cr.dispose
      rect.dispose
    end

    def line_number_area_paint_event(event)
      painter = Qt::Painter.new(@lineNumberArea)
      painter.setFont(font())
      # Check for weird bad initialization conditions
      if painter.isActive and not painter.paintEngine.nil?
        event_rect = event.rect()
        painter.fillRect(event_rect, Qt::lightGray)

        block = firstVisibleBlock()
        blockNumber = block.blockNumber()

        top, bottom = block_top_and_bottom(block)

        width = @lineNumberArea.width()
        height = @fontMetrics.height()
        ellipse_width = @fontMetrics.width(CHAR_57)
        painter.setPen(Cosmos::BLACK)
        while (block.isValid() and top <= event_rect.bottom())
          if (block.isVisible() and bottom >= event_rect.top())
            number = blockNumber + 1
            painter.drawText(0,               # x
                             top,             # y
                             width,           # width
                             height,          # height
                             Qt::AlignRight,  # flags
                             number.to_s)     # text

            if @enable_breakpoints and block.userState() == BREAKPOINT_SET
              painter.setBrush(Cosmos::RED)
              painter.drawEllipse(2,
                                  top+2,
                                  ellipse_width,
                                  ellipse_width)
            end
          end

          next_block = block.next()
          block.dispose
          block = next_block
          top = bottom
          rect = blockBoundingRect(block)
          bottom = top + rect.height()
          rect.dispose
          blockNumber += 1
        end
        block.dispose
        block = nil
        event_rect.dispose
        event_rect = nil
      end
      # Ensure the painter is disposed in the paint function to avoid this:
      #   QPaintDevice: Cannot destroy paint device that is being painted
      painter.dispose
      painter = nil
    end

    private

    def line_count_changed(new_block_count)
      if new_block_count >= 0
        update_breakpoints()
      end
      setViewportMargins(line_number_area_width(), 0, 0, 0)
      update
    end

    def update_line_number_area(rect, dy)
      if (dy)
        @lineNumberArea.scroll(0, dy)
      else
        @lineNumberArea.update(0, rect.y(), @lineNumberArea.width(), rect.height())
      end
      my_viewport = viewport()
      viewport_rect = my_viewport.rect()
      line_count_changed(-1) if (rect.contains(viewport_rect))
      viewport_rect.dispose
    end

    def line_number_area_width
      digits = 1
      my_document = document()
      max = [1, my_document.blockCount()].max

      # Figure the line number power of ten to determine how much space we need
      while (max >= 10)
        max /= 10
        digits += 1
      end
      # We'll always display space for 5 digits so the line number area
      # isn't constantly expanding and contracting
      digits = 5 if digits < 5
      digits += 1 # always allow room for a breakpoint symbol
      # Get the font width of the character 57 ('9')
      # times the number of digits to display
      return (3 + @fontMetrics.width(CHAR_57) * digits)
    end

    def line_at_point(point)
      block_num = firstVisibleBlock().blockNumber()
      while block_num < document.blockCount()
        block = document.findBlockByNumber(block_num)
        top, bottom = block_top_and_bottom(block)
        if (top..bottom).include?(point.y)
          yield block_num + 1
          break
        end
        block_num += 1
      end
    end

    def create_add_breakpoint_action(point)
      action = Qt::Action.new("Add Breakpoint", self)
      action.statusTip = "Add a breakpoint at this line"
      action.connect(SIGNAL('triggered()')) do
        line_at_point(point) do |line|
          add_breakpoint(line)
          emit breakpoint_set(line)
        end
      end
      action
    end

    def create_clear_breakpoint_action(point)
      action = Qt::Action.new("Clear Breakpoint", self)
      action.statusTip = "Clear an existing breakpoint at this line"
      action.connect(SIGNAL('triggered()')) do
        line_at_point(point) do |line|
          clear_breakpoint(line)
          emit breakpoint_cleared(line)
        end
      end
      action
    end

    def create_clear_all_breakpoints_action
      action = Qt::Action.new("Clear All Breakpoints", self)
      action.statusTip = "Clear all existing breakpoints"
      action.connect(SIGNAL('triggered()')) do
        clear_breakpoints
        emit breakpoints_cleared
      end
      action
    end

    # Get the top and bottom coordinates of the block in viewport coordinates
    def block_top_and_bottom(block)
      # bounding rect of the text block in content coordinates
      rect = blockBoundingGeometry(block)
      offset = contentOffset() # content origin in viewport coordinates
      # translate the rect to get visual coordinates on the viewport
      rect2 = rect.translated(offset)
      top = rect2.top()
      # bounding rect in block coordinates
      rect3 = blockBoundingRect(block)
      bottom = top + rect3.height()
      # Now call the destructors and set to nil to allow garbage collection
      offset.dispose
      offset = nil
      rect.dispose
      rect = nil
      rect2.dispose
      rect2 = nil
      rect3.dispose
      rect3 = nil
      return top, bottom
    end
  end

end # module Cosmos
