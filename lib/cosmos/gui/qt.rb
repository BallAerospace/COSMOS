# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file require QT for use by COSMOS.  It exists to provide a location for
# adding workarounds should they be needed to work through problems with
# interacting with QT from Ruby.

require 'stringio'
require 'cosmos'
check_filename = File.join(Cosmos::USERPATH, "#{File.basename($0, File.extname($0))}_qt_check.txt")
qt_in_system_folder = false

# Check for Qt dlls in Window system folders
if Kernel.is_windows?
  windir =  ENV['SystemRoot']
  if windir
    # Check Windows system folders for existing Qt dll files
    ['system', 'SysWOW64', 'System32'].each do |folder|
      break if qt_in_system_folder
      ['libgcc_s_dw2-1.dll',
       'mingwm10.dll',
       'phonon4.dll',
       'Qt3Support4.dll',
       'QtCLucene4.dll',
       'QtCore4.dll',
       'QtDeclarative4.dll',
       'QtDesigner4.dll',
       'QtDesignerComponents4.dll',
       'QtGui4.dll',
       'QtHelp4.dll',
       'QtMultimedia4.dll',
       'QtNetwork4.dll',
       'QtOpenGL4.dll',
       'QtScript4.dll',
       'QtScriptTools4.dll',
       'QtSql4.dll',
       'QtSvg4.dll',
       'QtTest4.dll',
       'QtWebKit4.dll',
       'QtXml4.dll',
       'QtXmlPatterns4.dll'].each do |qtfilename|
        break if qt_in_system_folder
        filename = File.join(windir, folder, qtfilename)
        if File.exist?(filename)
          qt_in_system_folder = true

          # Is this the first time we've detected this?
          if File.exist?(check_filename)
            # We tried before and failed
            File.delete(check_filename)

            if $0 =~ /Launcher/
              require 'cosmos/win32/win32'
              Cosmos::Win32.message_box("Found conflicting Qt dll file at: #{filename}\nPlease overwrite all Qt dlls in the Windows system folders with the newest Qt4 version (or delete them).")
            end
            raise "Found conflicting Qt dll file at: #{filename}. Please overwrite all Qt dlls in the Windows system folders with the newest Qt4 version (or delete them)."
          else
            # First Time we've detected this - We'll create it and risk just requiring Qt once
            File.open(check_filename, 'w') {|file| file.write("Qt Dll Check In Progress")}
          end
        end
      end
    end
  end
end

if Kernel.is_windows?
  temp_stderr = $stderr.clone
  $stderr.reopen(File.new('nul', 'w'))
end
# This will either lock up or raise an error if older Qt dlls are present in the Windows system folders
begin
  require 'Qt'
ensure
  $stderr.reopen(temp_stderr) if Kernel.is_windows?
end
File.delete(check_filename) if Kernel.is_windows? and File.exist?(check_filename)

module Cosmos
  BIN_FILE_PATTERN = "Bin Files (*.bin);;All Files (*)"
  TXT_FILE_PATTERN = "Txt Files (*.txt);;All Files (*)"
  CSV_FILE_PATTERN = "Csv Files (*.csv);;All Files (*)"
  CMD_FILE_PATTERN = "Cmd Log Files (*cmd*.bin);;Bin Files (*.bin);;All Files (*)"
  TLM_FILE_PATTERN = "Tlm Log Files (*tlm*.bin);;Bin Files (*.bin);;All Files (*)"
  COLORS = {}
  BRUSHES = {}
  PALETTES = {}
  PENS = {}
  FONTS = {}
  FONT_METRICS = {}
  CURSORS = {}

  def self.getColor(color_r, color_g = nil, color_b = nil)
    return color_r if (color_r.is_a? Qt::Color) || (color_r.is_a? Qt::Pen) || (color_r.is_a? Qt::LinearGradient)

    color = nil
    key = color_r
    key = key.to_i if key.is_a? Qt::Enum

    if color_r && color_g && color_b
      key = (color_r.to_i << 24) + (color_g.to_i << 16) + (color_b.to_i << 8)
    end

    if Cosmos::COLORS[key]
      color = Cosmos::COLORS[key]
    else
      if color_r && color_g && color_b
        color = Qt::Color.new(color_r.to_i, color_g.to_i, color_b.to_i)
      else
        color = Qt::Color.new(color_r)
      end
      Cosmos::COLORS[key] = color
    end
    color
  end

  def self.getBrush(color)
    return nil unless color
    return color if color.is_a? Qt::Brush
    brush = nil
    color = Cosmos.getColor(color)
    brush = BRUSHES[color]
    unless brush
      if color.is_a? Qt::LinearGradient
        brush = Qt::Brush.new(color)
      else
        brush = Qt::Brush.new(color, Qt::SolidPattern)
      end
      BRUSHES[color] = brush
    end
    brush
  end

  def self.getPalette(foreground, background)
    foreground = Cosmos.getColor(foreground)
    background = Cosmos.getColor(background)
    PALETTES[foreground] ||= {}
    p = PALETTES[foreground][background]
    unless p
      p = Qt::Palette.new
      p.setColor(Qt::Palette::Text, foreground)
      p.setColor(Qt::Palette::Base, background)
      p.setColor(Qt::Palette::Window, background)
      PALETTES[foreground][background] = p
    end
    p
  end

  def self.getPen(color = nil)
    color = Cosmos.getColor(color) if color
    pen = nil
    pen = PENS[color]
    unless pen
      if color
        pen = Qt::Pen.new(color)
      else
        pen = Qt::Pen.new
      end
      PENS[color] = pen
    end
    pen
  end

  def self.getFont(font_face, font_size, font_attrs = nil, font_italics = false)
    FONTS[font_face] ||= {}
    FONTS[font_face][font_size] ||= {}
    FONTS[font_face][font_size][font_attrs] ||= {}
    font = FONTS[font_face][font_size][font_attrs][font_italics]
    unless font
      if font_attrs && font_italics
        font = Qt::Font.new(font_face, font_size, font_attrs, font_italics)
      elsif font_attrs
        font = Qt::Font.new(font_face, font_size, font_attrs)
      else
        font = Qt::Font.new(font_face, font_size)
      end
      FONTS[font_face][font_size][font_attrs][font_italics] = font
    end
    font
  end

  # Get the default small font for the platform (Windows, Mac, Linux)
  def self.get_default_small_font
    if Kernel.is_windows?
      Cosmos.getFont("courier", 9)
    else
      Cosmos.getFont("courier", 12)
    end
  end

  # Get the default font for the platform (Windows, Mac, Linux)
  def self.get_default_font
    if Kernel.is_windows?
      Cosmos.getFont("Courier", 10)
    else
      Cosmos.getFont("Courier", 14)
    end
  end

  def self.getFontMetrics(font)
    font_metrics = FONT_METRICS[font]
    unless font_metrics
      font_metrics = Qt::FontMetrics.new(font)
      FONT_METRICS[font] = font_metrics
    end
    font_metrics
  end

  def self.getCursor(shape)
    key = shape
    key = shape.to_i if shape.is_a? Qt::Enum
    cursor = CURSORS[key]
    unless cursor
      cursor = Qt::Cursor.new(shape)
      CURSORS[key] = cursor
    end
    cursor
  end

  GREEN = getColor(0, 150, 0)
  YELLOW = getColor(190, 135, 0)
  RED = getColor(Qt::red)
  BLUE = getColor(0, 100, 255)
  PURPLE = getColor(200, 0, 200)
  BLACK = getColor(Qt::black)
  WHITE = getColor(Qt::white)
  BLACK_NO_BRUSH = Qt::Brush.new(Cosmos::BLACK, Qt::NoBrush)
  DEFAULT_PALETTE = Qt::Palette.new
  RED_PALETTE = Qt::Palette.new(Qt::red)
  DASHLINE_PEN = Qt::Pen.new(Qt::DashLine)

  # Load the applications icon
  def self.load_cosmos_icon(name='COSMOS_64x64.png')
    icon = Cosmos.get_icon(name, false)
    icon = Cosmos.get_icon('COSMOS_64x64.png', false) unless icon
    Qt::Application.instance.setWindowIcon(icon) if icon
    return icon
  end

  # Load the applications icon
  def self.get_icon(name, fail_blank = true)
    icon = Qt::Icon.new(Cosmos.data_path(name))
    icon = nil if icon.isNull && !fail_blank
    return icon
  end

  # Try to change to a configuration in a packet log reader
  def self.check_log_configuration(packet_log_reader, log_filename)
    config_change_success, change_error = packet_log_reader.open(log_filename)
    unless config_change_success
      Qt.execute_in_main_thread(true) do
        if change_error
          Qt::MessageBox.warning(Qt::Application.instance.activeWindow, 'Warning', "When opening: #{log_filename}\n\nAn error occurred when changing to saved configuration:\n#{packet_log_reader.configuration_name}\n\n#{change_error.formatted}\n\nUsing default configuration")
        else
          Qt::MessageBox.warning(Qt::Application.instance.activeWindow, 'Warning', "When opening: #{log_filename}\n\nThe following saved configuration was not found:\n#{packet_log_reader.configuration_name}\n\nUsing default configuration")
        end
      end
    end
  end
end

class Qt::CheckboxLabel < Qt::Label
  def setCheckbox(checkbox)
    @checkbox = checkbox
  end

  def mouseReleaseEvent(event)
    @checkbox.toggle
  end
end

class Qt::Icon
  def initialize(param = nil)
    if param
      super(param)
    else
      super()
    end
  end
end

class Qt::Dialog
  def initialize(parent = Qt::Application.activeWindow,
                 flags = (Qt::WindowTitleHint | Qt::WindowSystemMenuHint))
    super(parent, flags)
  end
end

class Qt::TableWidget
  # Resizes the table, turns off scroll bars, and sets the minimum and maximum sizes
  # to the full size of the table with all the elements in view
  def displayFullSize
    resizeColumnsToContents()
    resizeRowsToContents()
    setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOff)
    setVerticalScrollBarPolicy(Qt::ScrollBarAlwaysOff)
    setMinimumSize(fullWidth, fullHeight)
    setMaximumSize(fullWidth, fullHeight)
  end

  def fullWidth
    2*frameWidth() + horizontalHeader.length + verticalHeader.width
  end

  def fullHeight
    2*frameWidth() + verticalHeader.length + horizontalHeader.height
  end
end

class Qt::TableWidgetItem
  def initialize(string = "")
    super(string)
    setFlags(Qt::ItemIsEnabled)
  end

  def textColor=(color)
    setForeground(Cosmos.getBrush(color))
  end
end

class Qt::TreeWidget
  def initialize(parent = Qt::Application.activeWindow)
    super(parent)

    # Create a sensible default handler for clicking the checkboxes
    # of a tree. If you check a node all the lower nodes get checked.
    # If you uncheck a node all the lower nodes get unchecked.
    # If you check a lower node all the parent nodes get checked.
    connect(SIGNAL('itemClicked(QTreeWidgetItem*, int)')) do |node, col|
      if node.checkState == Qt::Checked
        # Set all nodes below this to checked
        node.setCheckStateAll(Qt::Checked)

        # Set all the nodes above this to checked
        while node.parent
          node = node.parent
          node.setCheckState(0, Qt::Checked)
        end
      else
        # Set all nodes below this to unchecked
        node.setCheckStateAll(Qt::Unchecked)
      end
    end
  end

  # Yields each of the top level items (those without a parent).
  def topLevelItems
    topLevelItemCount.times do |index|
      yield topLevelItem(index)
    end
  end
end

class Qt::TreeWidgetItem
  # Sets the check state of this TreeWidgetItem as well as all its children
  # recursively.
  #
  # @param state [Integer] Must be Qt::Checked or Qt::Unchecked
  def setCheckStateAll(state = Qt::Checked)
    children() do |child|
      child.setCheckStateAll(state)
    end
    setCheckState(0, state)
  end

  # @return [Qt::TreeWidgetItem] The top level item for this TreeWidgetItem.
  #   The top level item does not have a parent. Note that this could return
  #   itself.
  def topLevel
    top = self
    if !top.parent.nil?
      while true
        top = top.parent
        break if top.parent.nil?
      end
    end
    top
  end

  # Yields the children of the current node
  def children
    childCount.times do |index|
      yield child(index)
    end
  end

  # Define the default column to be 0
  def background(column = 0)
    super(column)
  end
  def checkState(column = 0)
    super(column)
  end
  def font(column = 0)
    super(column)
  end
  def foreground(column = 0)
    super(column)
  end
  def icon(column = 0)
    super(column)
  end
  def statusTip(column = 0)
    super(column)
  end
  def sizeHint(column = 0)
    super(column)
  end
  def text(column = 0)
    super(column)
  end
  def toolTip(column = 0)
    super(column)
  end
  def whatsThis(column = 0)
    super(column)
  end
end

class Qt::TabWidget
  def current_name
    tabText(currentIndex)
  end

  def tab(tab_text)
    (0...count()).each do |index|
      return widget(index) if tabText(index) == tab_text
    end
    nil
  end

  def widgets
    all = []
    (0...self.count()).each do |index|
      all << self.widget(index)
    end
    all
  end
  alias :tabs :widgets

  def currentWidget
    self.widget(self.currentIndex)
  end
  alias :currentTab :currentWidget
end

class Qt::LineEdit
  def setColors(foreground, background)
    setPalette(Cosmos.getPalette(foreground, background))
  end

  def text=(value)
    setText(value)
  end
end

class Qt::PlainTextEdit
  BLANK = ''.freeze
  BREAK = '<br/>'.freeze
  AMP = '&amp;'.freeze
  NBSP = '&nbsp;'.freeze
  GT = '&gt;'.freeze
  LT = '&lt;'.freeze
  @@color_cache = {}
  @@mapping = {'&'=>AMP,"\n"=>BLANK,"\s"=>NBSP,'>'=>GT,'<'=>LT}
  @@regex = Regexp.union(@@mapping.keys)

  def add_formatted_text(text, color = nil)
    if text =~ /[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F-\xFF]/
      text.chomp!
      text = text.inspect.remove_quotes
      text << "\n"
    end
    if text =~ /<G>/ or color == Cosmos::GREEN
      addText(text.gsub(/<G>/, BLANK), Cosmos::GREEN)
    elsif text =~ /<Y>/ or color == Cosmos::YELLOW
      addText(text.gsub(/<Y>/, BLANK), Cosmos::YELLOW)
    elsif text =~ /<R>/ or color == Cosmos::RED
      addText(text.gsub(/<R>/, BLANK), Cosmos::RED)
    elsif text =~ /<B>/ or color == Cosmos::BLUE
      addText(text.gsub(/<B>/, BLANK), Cosmos::BLUE)
    else
      addText(text) # default is Cosmos::BLACK
    end
  end

  def addText(text, color = Cosmos::BLACK)
    @current_text ||= ''
    @current_text << escape_text(text.chomp, color) << BREAK
  end

  def flush
    appendHtml(@current_text)
    @current_text.clear
  end

  def appendText(text, color = Cosmos::BLACK)
    appendHtml(escape_text(text.chomp, color))
  end

  # Return the selected lines. If a partial line is selected the entire line will be returned.
  # If there is no selection the line with the cursor will be returned
  def selected_lines
    cursor = textCursor
    selection_end = cursor.selectionEnd
    # Initially place the cursor at the beginning of the selection
    # If nothing is selected this will just put the cursor at the beginning of the current line
    cursor.setPosition(textCursor.selectionStart)
    cursor.movePosition(Qt::TextCursor::StartOfLine)
    # Move the cursor to the end of the selection while keeping the anchor
    cursor.setPosition(selection_end, Qt::TextCursor::KeepAnchor)
    # Normally we want to select the entire line where the end of selection is
    # However if the user selects an exact number of lines
    # the cursor will be at the beginning of the following line
    # Therefore if the cursor is at the beginning of the line and we have a selection
    # we'll skip moving to the end of the line
    unless (cursor.atBlockStart and textCursor.hasSelection)
      cursor.movePosition(Qt::TextCursor::EndOfLine, Qt::TextCursor::KeepAnchor)
    end
    # If there is no selection then just return nil
    return nil if cursor.selectedText.nil?

    cursor.selection.toPlainText

    # The selectedText function returns the Unicode U+2029 paragraph separator character
    # instead of newline \n. Thus we have to unpack as Unicode, covert to newlines, and then repack
    #text = cursor.selectedText.unpack("U*")
    #text.collect! {|letter| if letter == 63 then 10 else letter end }
    #text.pack("U*")
  end

  # Return the line number (0 based) of the selection start
  def selection_start_line
    cursor = textCursor
    cursor.setPosition(textCursor.selectionStart)
    cursor.blockNumber
  end

  # Return the line number (0 based) of the selection end
  def selection_end_line
    cursor = textCursor
    cursor.setPosition(textCursor.selectionEnd)
    cursor.blockNumber
  end

  private
  def escape_text(text, color)
    @@color_cache[color] ||= "#%02X%02X%02X" % [color.red, color.green, color.blue]
    # You might think gsub! would use less memory but benchmarking proves gsub
    # with a regular express argument is the fastest and uses the least memory.
    # However, this is still an expensive operation due to how many times it is called.
    "<font color=\"#{@@color_cache[color]}\">#{text.gsub(@@regex,@@mapping)}</font>"
  end
end

class Qt::TextEdit
  def setColors(foreground, background)
    setPalette(Cosmos.getPalette(foreground, background))
  end
end

class Qt::ComboBox
  # Helper method to remove all items from a ComboBox
  def clearItems
    (0...count).to_a.reverse_each do |index|
      removeItem(index)
    end
  end

  # Alias currentText as text to make it more compatible with LineEdit which uses text
  def text
    currentText
  end

  # Helper method to set the current item using a text String instead of the index
  def setCurrentText(arg)
    setCurrentIndex(findText(arg.to_s))
  end

  def each
    (0...count).each do |index|
      yield self.itemText(index), self.itemData(index)
    end
  end
end

class Qt::ListWidget
  # Helper method to remove all items from a ListWidget
  def clearItems
    (0...count).each do
      takeItem(0).dispose
    end
  end

  def each
    (0...count).each do |index|
      yield self.item(index)
    end
  end

  def remove_selected_items
    # Take the selected items and call row on each to get an array of the item indexes
    # Sort that array because selectedItems is returned in the order selected, not numerical order
    # Reverse this array of indices so we remove the last item first,
    # this allows all the indexes to remain constant
    # Call takeItem of each of the indices and then dispose the resulting ListWidgetItem that is returned
    selectedItems.map {|x| row(x)}.sort.reverse.each { |index| takeItem(index).dispose }
  end
end

# This class attempts to duplicate Fox's FXColorList
# by adding a colored icon to each item in the ListWidget
class Qt::ColorListWidget < Qt::ListWidget
  attr_reader :original_parent

  def initialize(parent, enable_key_delete = true)
    super(parent)
    # When a layout adds this widget it automatically gets re-parented so
    # store the original parent in case someone needs it
    @original_parent = parent
    @enable_key_delete = enable_key_delete
    @colors = []
    @maps = []
    @icons = []
    setUniformItemSizes(true)
  end

  def resize_to_contents
    return if count == 0
    #setResizeMode(Qt::ListView::Adjust)
    # Disable the vertical scrollbar and don't display it
    verticalScrollBar.setDisabled(true)
    setVerticalScrollBarPolicy(Qt::ScrollBarAlwaysOff)
    # Get the height of an item and multiply by the number of items
    setFixedHeight(visualItemRect(item(0)).height * (count + 1))
  end

  def set_read_only
    setSelectionMode(Qt::AbstractItemView::NoSelection)
    filter = Qt::Object.new
    filter.define_singleton_method(:eventFilter) do |obj, event|
      if event.type == Qt::Event::KeyPress &&
        (event.key == Qt::Key_Delete || event.key == Qt::Key_Backspace)
        return true
      end
      return false
    end
    installEventFilter(filter)
  end

  def keyPressEvent(event)
    if @enable_key_delete
      if (event.key == Qt::Key_Delete || event.key == Qt::Key_Backspace)
        takeItemColor(currentRow)
      end
    end
    super(event)
  end

  def addItemColor(text, color = Cosmos::BLACK)
    @colors << color
    @maps << Qt::Pixmap.new(20,14)
    color = Cosmos::getColor(color)
    @maps[-1].fill(color)
    icon = Qt::Icon.new
    icon.addPixmap(@maps[-1], Qt::Icon::Normal)
    icon.addPixmap(@maps[-1], Qt::Icon::Selected)
    @icons << icon
    item = Qt::ListWidgetItem.new(@icons[-1], text.to_s)
    addItem(item)
  end

  def getItemColor(index)
    @colors[index]
  end

  def takeItemColor(row)
    item = takeItem(row)
    if item
      @colors.delete_at(row)
      @maps.delete_at(row).dispose
      @icons.delete_at(row).dispose
      item.dispose
    end
  end

  def clearItems
    (0...count).each do
      takeItemColor(0)
    end
  end

  def dispose
    super()
    @maps.each {|map| map.dispose}
    @icons.each {|icon| icon.dispose}
  end
end

class Qt::Painter
  def setPen(pen_color)
    super(Cosmos::getColor(pen_color))
    @pen_color = pen_color
  end
  def setBrush(brush)
    super(Cosmos::getBrush(brush))
    @brush = brush
  end

  def addLineColor(x, y, w, h, color = Cosmos::BLACK)
    setPen(color) if color != @pen_color
    drawLine(x,y,w,h)
  end

  def addRectColor(x, y, w, h, color = Cosmos::BLACK)
    setPen(color) if color != @pen_color
    setBrush(nil) if @brush
    drawRect(x,y,w,h)
  end

  # Note if brush_color is not specified it will be the same as pen_color
  def addRectColorFill(x, y, w, h, pen_color = Cosmos::BLACK, brush_color = nil)
    setPen(pen_color) if pen_color != @pen_color
    brush_color = pen_color unless brush_color
    setBrush(brush_color) if brush_color != @brush
    drawRect(x,y,w,h)
  end

  def addSimpleTextAt(text, x, y, color = Cosmos::BLACK)
    setPen(color) if color != @pen_color
    drawText(x,y,text)
  end

  def addEllipseColor(x, y, w, h, color = Cosmos::BLACK)
    setPen(color) if color != @pen_color
    setBrush(nil) if @brush
    drawEllipse(x,y,w,h)
  end

  # Note if brush_color is not specified it will be the same as pen_color
  def addEllipseColorFill(x, y, w, h, pen_color = Cosmos::BLACK, brush_color = nil)
    setPen(pen_color) if pen_color != @pen_color
    brush_color = pen_color unless brush_color
    setBrush(brush_color) if brush_color != @brush
    drawEllipse(x,y,w,h)
  end
end

class Qt::MatrixLayout < Qt::GridLayout
  def initialize(num_columns)
    super(nil)
    @num_columns = num_columns
    @row = 0
    @col = 0
  end

  def addWidget(widget)
    super(widget, @row, @col)
    increment_row_col()
  end

  def addLayout(layout)
    super(layout, @row, @col)
    increment_row_col()
  end

  private

  def increment_row_col
    @col += 1 if @col < @num_columns
    if @col == @num_columns
      @row += 1
      @col = 0
    end
  end
end

class Qt::AdaptiveGridLayout < Qt::GridLayout
  def addWidget(widget)
    case (count() + 1)
    when 3 # reorder things to add a second column
      old = takeAt(1)
      addItem(old, 0, 1)
      super(widget)
    when 7 # reorder everything to add a third column
      items = []
      # Take the items in reverse order because taking an item changes the indexes
      5.downto(2).each {|index| items << takeAt(index)}
      # Reverse the items to get them back into insertion order
      items.reverse!
      addItem(items[0], 0, 2)
      addItem(items[1], 1, 0)
      addItem(items[2], 1, 1)
      addItem(items[3], 1, 2)
      super(widget)
    # When we have established the desired number of rows we can add things and GridLayout does the right thing
    else
      super(widget)
    end
  end
  # removeWidget is not implemented. If you want to remove widgets, transfer the existing to a new layout like so:
  # (0...old_layout.count).each do |index|
    # new_layout.addWidget(old_layout.takeAt(0).widget)
  # end
end

# Implement removeAll on all the layout managers.
# It would be easier to add this method on Qt::Layout which is the parent class to all but
# that doesn't work due to the way method_missing is used to call the actual method
%w(GridLayout BoxLayout VBoxLayout HBoxLayout FormLayout StackedLayout).each do |klass|
  "Qt::#{klass}".to_class.class_eval do
    def removeAll
      (0...count).each do |index|
        item = takeAt(0)
        if item.layout
          item.removeAll
        else
          item.widget.dispose if item.widget
        end
      end
    end
  end
end

class Qt::BoxLayout
  def initialize(*args)
    super(*args)
    setSpacing(5) if Kernel.is_mac?
  end
end

class Qt::VBoxLayout
  def initialize(*args)
    super(*args)
    setSpacing(5) if Kernel.is_mac?
  end
end

class Qt::HBoxLayout
  def initialize(*args)
    super(*args)
    setSpacing(5) if Kernel.is_mac?
  end
end

class Qt::GridLayout
  def initialize(*args)
    super(*args)
    setSpacing(5) if Kernel.is_mac?
  end
end
