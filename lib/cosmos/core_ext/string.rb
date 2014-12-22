# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/packets/binary_accessor'
require 'cosmos/ext/string'

# COSMOS specific additions to the Ruby String class
class String

  # The printable range of ASCII characters
  PRINTABLE_RANGE = 32..126
  # Regular expression to identify a String as a floating point number
  FLOAT_CHECK_REGEX = /^\s*[-+]?\d*\.\d+\s*$/
  # Regular expression to identify a String as a floating point number in
  # scientific notation
  SCIENTIFIC_CHECK_REGEX = /^\s*[-+]?(\d+((\.\d+)?)|(\.\d+))[eE][-+]?\d+\s*$/
  # Regular expression to identify a String as an integer
  INT_CHECK_REGEX = /^\s*[-+]?\d+\s*$/
  # Regular expression to identify a String as an integer in hexadecimal format
  HEX_CHECK_REGEX = /^\s*0[xX][\dabcdefABCDEF]+\s*$/
  # Regular expression to identify a String as an Array of numbers
  ARRAY_CHECK_REGEX = /^\s*\[.*\]\s*$/

  # Displays a String containing binary data in a human readable format by
  # converting each byte to the hex representation.
  #
  # @param word_size [Integer] How many bytes compose a word. Words are grouped
  #   together without spaces in between
  # @param words_per_line [Integer] The number of words to display on a single
  #   formatted line
  # @param word_separator [String] The string to place between words
  # @param indent [Integer] The amount of spaces to put in front of each
  #   formatted line
  # @param show_address [Boolean] Whether to show the hex address of the first
  #   byte in the formatted output
  # @param address_separator [String] The string to put after the hex address.
  #   Only used if show_address is true.
  # @param show_ascii [Boolean] Whether to interpret the binary data as ASCII
  #   characters and display the printable characters to the right of the
  #   formatted line
  # @param ascii_separator [String] The string to put between the formatted
  #   line and the ASCII characters. Only used if show_ascii is true.
  # @param unprintable_character [String] The string to output when data in the
  #   binary String does not result in a printable ASCII character. Only used if
  #   show_ascii is true.
  # @param line_separator [String] The string used to end a line.  Normaly newline.
  def formatted(
    word_size = 1,
    words_per_line = 16,
    word_separator = ' ',
    indent = 0,
    show_address = true,
    address_separator = ': ',
    show_ascii = true,
    ascii_separator = '  ',
    unprintable_character = ' ',
    line_separator = "\n"
  )
    string = ''
    byte_offset = 0
    bytes_per_line = word_size * words_per_line
    indent_string = ' ' * indent
    ascii_line = ''

    self.each_byte do |byte|
      if byte_offset % bytes_per_line == 0
        # Create the indentation at the beginning of each line
        string << indent_string

        # Add the address if requested
        string << sprintf("%08X%s", byte_offset, address_separator) if show_address
      end

      # Add the byte
      string << sprintf("%02X", byte)

      # Create the ASCII representation if requested
      if show_ascii
        if PRINTABLE_RANGE.include?(byte)
          ascii_line << [byte].pack('C')
        else
          ascii_line << unprintable_character
        end
      end

      # Move to next byte
      byte_offset += 1

      # If we're at the end of the line we output the ascii if requested
      if byte_offset % bytes_per_line == 0
        if show_ascii
          string << "#{ascii_separator}#{ascii_line}"
          ascii_line = ''
        end
        string << line_separator

      # If we're at a word junction then output the word_separator
      elsif (byte_offset % word_size == 0) and byte_offset != self.length
        string << word_separator
      end
    end

    # We're done printing all the bytes. Now check to see if we ended in the
    # middle of a line. If so we have to print out the final ASCII if
    # requested.
    if byte_offset % bytes_per_line != 0
      if show_ascii
        num_word_separators = ((byte_offset % bytes_per_line) - 1) / word_size
        existing_length = (num_word_separators * word_separator.length) + ((byte_offset % bytes_per_line) * 2)
        full_line_length = (bytes_per_line * 2) + ((words_per_line - 1) * word_separator.length)
        filler = ' ' * (full_line_length - existing_length)
        ascii_filler = ' ' * (bytes_per_line - ascii_line.length)
        string << "#{filler}#{ascii_separator}#{ascii_line}#{ascii_filler}"
        ascii_line = ''
      end
      string << line_separator
    end
    string
  end

  # Displays a String containing binary data in a human readable format by
  # converting each byte to the hex representation.
  # Simply formatted as a single string of bytes
  def simple_formatted
    string = ''
    self.each_byte do |byte|
      string << sprintf("%02X", byte)
    end
    string
  end

  # Uses the String each_line method to interate through the lines and removes
  # the line specified.
  #
  # @param line_number [Integer] The line to remove from the string (1 based)
  # @param separator [String] The record separator to pass to #each_line
  #   ($/ by default is the newline character)
  # @return [String] A new string with the line removed
  def remove_line(line_number, separator=$/)
    new_string = ''
    index = 1
    self.each_line(separator) do |line|
      new_string << line unless index == line_number
      index += 1
    end
    new_string
  end

  # @return [Integer] The number of lines in the string (as split by the newline
  #   character)
  def num_lines
    value = self.count("\n")
    value += 1 if self[-1..-1] and self[-1..-1] != "\n"
    value
  end

  # @return [String] The string with leading and trailing quotes removed
  # def remove_quotes

  # @return [Boolean] Whether the String represents a floating point number
  def is_float?
    if self =~ FLOAT_CHECK_REGEX or self =~ SCIENTIFIC_CHECK_REGEX then true else false end
  end

  # @return [Boolean] Whether the String represents an integer
  def is_int?
    if self =~ INT_CHECK_REGEX then true else false end
  end

  # @return [Boolean] Whether the String represents a hexadecimal number
  def is_hex?
    if self =~ HEX_CHECK_REGEX then true else false end
  end

  # @return [Boolean] Whether the String represents an Array
  def is_array?
    if self =~ ARRAY_CHECK_REGEX then true else false end
  end

  # @return Converts the String into either a Float, Integer, or Array
  # depending on what the String represents. It can successfully convert
  # floating point numbers in both fixed and scientific notation, integers
  # in hexadecimal notation, and Arrays. If it can not be converted into
  # any of the above then the original String is returned.
  def convert_to_value
    return_value = self
    if self.is_float?
      # Floating Point in normal or scientific notation
      return_value = self.to_f
    elsif self.is_int?
      # Integer
      return_value = self.to_i
    elsif self.is_hex?
      # Hex
      return_value = Integer(self)
    elsif self.is_array?
      # Array
      return_value = eval(self)
    end
    return return_value
  end

  # Converts the String representing a hexadecimal number (i.e. "0xABCD")
  # to a binary String with the same data (i.e "\xAB\xCD")
  #
  # @return [String] Binary byte string
  def hex_to_byte_string
    string = self.dup

    # Remove leading 0x or 0X
    if string[0..1] == '0x' or string[0..1] == '0X'
      string = string[2..-1]
    end

    length = string.length
    length += 1 unless (length % 2) == 0

    array = []
    (length / 2).times do
      # Grab last two characters
      if string.length >= 2
        last_two_characters = string[-2..-1]
        string = string[0..-3]
      else
        last_two_characters = string[0..0]
        string = ''
      end

      int_value = Integer('0x' + last_two_characters)

      array.unshift(int_value)
    end

    array.pack("C*")
  end

  # Converts a String representing a class (i.e. "MyGreatClass") to a Ruby
  # filename which implements the class (i.e. "my_great_class.rb").
  #
  # @return [String] Filename which implements the class name
  def class_name_to_filename
    filename = ''
    length = self.length
    length.times do |index|
      filename << '_' if index != 0 and self[index..index] == self[index..index].upcase
      filename << self[index..index].downcase
    end
    filename << '.rb'
    filename
  end

  # Converts a String representing a filename (i.e. "my_great_class.rb") to a Ruby
  # class name (i.e. "MyGreatClass").
  #
  # @return [String] Class name associated with the filename
  def filename_to_class_name
    filename = File.basename(self)
    class_name  = ''
    length      = filename.length
    upcase_next = true
    length.times do |index|
      break if filename[index..index] == '.'
      if filename[index..index] == '_'
        upcase_next = true
      elsif upcase_next
        class_name << filename[index..index].upcase
        upcase_next = false
      else
        class_name << filename[index..index].downcase
      end
    end
    class_name
  end

  # Converts a String representing a class (i.e. "MyGreatClass") to the actual
  # class that has been required and is present in the Ruby runtime.
  #
  # @return [Class]
  def to_class
    klass = nil
    split_self = self.split('::')
    if split_self.length > 1
      split_self.each do |class_name|
        if klass
          klass = klass.const_get(class_name)
        else
          klass = Object.const_get(class_name)
        end
      end
    else
      begin
        klass = Cosmos.const_get(self)
      rescue
        begin
          klass = Object.const_get(self)
        rescue
        end
      end
    end
    klass
  end

end # class String
