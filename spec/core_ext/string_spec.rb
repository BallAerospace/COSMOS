# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/core_ext/string'

describe String do

  describe "formatted" do
    before(:each) do
      @data = []
      (26..47).each {|x| @data << x }
      @data = @data.pack('C*')
    end

    it "uses 1 byte words" do
      expect(@data.formatted.split("\n")[0]).to eql "00000000: 1A 1B 1C 1D 1E 1F 20 21 22 23 24 25 26 27 28 29         !\"#\$%&\'\(\)"
      expect(@data.formatted.split("\n")[1]).to eql "00000010: 2A 2B 2C 2D 2E 2F                                *+,-./          "
    end

    it "uses 2 byte words" do
      expect(@data.formatted(2, 8)).to match "00000000: 1A1B 1C1D 1E1F" # ...
      expect(@data.formatted(2, 8)).to match "00000010: 2A2B 2C2D 2E2F"
    end

    it "changes the word separator" do
      expect(@data.formatted(2, 4, '_')).to match "00000000: 1A1B_1C1D_1E1F_2021"
      expect(@data.formatted(2, 4, '_')).to match "00000008: 2223_2425_2627_2829"
      expect(@data.formatted(2, 4, '_')).to match "00000010: 2A2B_2C2D_2E2F"
    end

    it "indents the lines" do
      expect(@data.formatted(1, 16, ' ', 4)).to match "    00000000: 1A 1B 1C 1D"
    end

    it "does not show the address" do
      expect(@data.formatted(1, 16, ' ', 0, false)).to match "1A 1B 1C 1D"
    end

    it "changes the address separator" do
      expect(@data.formatted(1, 16, ' ', 0, true, '= ')).to match "00000000= 1A 1B 1C 1D"
    end

    it "does not show the ASCII" do
      expect(@data.formatted(1,16,'',0,true,'',true)).to match '29         !"#\$%&\'()'
      expect(@data.formatted(1,16,'',0,true,'',false)).not_to match '29         !"#\$%&\'()'
    end

    it "changes the ASCII separator" do
      expect(@data.formatted(1,16,'',0,true,'',true,'__')).to match '29__       !"#\$%&\'()'
    end

    it "changes the ASCII unprintable character" do
      expect(@data.formatted(1,16,'',0,true,'',true,'__','x')).to match '29__xxxxxx !"#\$%&\'()'
    end

    it "changes the line separator" do
      expect(@data.formatted(1,16,' ',0,true,': ',true,'  ',' ', '~').split("~")[0]).to eql "00000000: 1A 1B 1C 1D 1E 1F 20 21 22 23 24 25 26 27 28 29         !\"#\$%&\'\(\)"
      expect(@data.formatted(1,16,' ',0,true,': ',true,'  ',' ', '~').split("~")[1]).to eql "00000010: 2A 2B 2C 2D 2E 2F                                *+,-./          "
    end
  end

  describe "simple_formatted" do
    before(:each) do
      @data = []
      (26..47).each {|x| @data << x }
      @data = @data.pack('C*')
    end

    it "formats the data" do
      expect(@data.simple_formatted).to eql "1A1B1C1D1E1F202122232425262728292A2B2C2D2E2F"
    end
  end

  describe "remove_line" do
    it "removes the specified line" do
      test = "this\nis\na\ntest"
      expect(test.remove_line(1)).to eql "is\na\ntest"
      expect(test).to eql "this\nis\na\ntest"
    end

    it "splits on the given separator" do
      test = "thisXisXaXtest"
      expect(test.remove_line(4,'X')).to eql "thisXisXaX"
    end

    it "does nothing if the line number isn't found" do
      test = "thisXisXaXtest"
      expect(test.remove_line(5,'X')).to eql "thisXisXaXtest"
    end
  end

  describe "num_lines" do
    it "counts the number of newlines" do
      test = "this\nis\na\ntest"
      expect(test.num_lines).to eql 4
    end

    it "does not count trailing newlines" do
      test = "this\nis\na\ntest\n"
      expect(test.num_lines).to eql 4
    end
  end

  describe "remove_quotes" do
    context "with single quotes" do
      it "removes leading and trailing single quotes" do
        test = "'string'"
        expect(test.remove_quotes).to eql "string"
      end

      it "does not remove interior" do
        test = "can't"
        expect(test.remove_quotes).to eql "can't"
      end
    end

    context "with double quotes" do
      it "removes leading and trailing" do
        test = '"string"'
        expect(test.remove_quotes).to eql "string"
      end

      it "does not remove interior" do
        test = 'say("HI")'
        expect(test.remove_quotes).to eql 'say("HI")'
      end
    end
  end

  describe "is_float?" do
    it "returns true if it's a float" do
      expect("hi".is_float?).to be false
      expect("hi 5.5".is_float?).to be false
      expect("5.5 hi".is_float?).to be false
      expect("515".is_float?).to be false
      expect("515.0".is_float?).to be true
      expect(" 515.0 ".is_float?).to be true
      expect("5.123E5".is_float?).to be true
    end
  end

  describe "is_int?" do
    it "returns true if it's an integer" do
      expect("hi".is_int?).to be false
      expect("hi 5".is_int?).to be false
      expect("5 hi".is_int?).to be false
      expect("515.0".is_int?).to be false
      expect("515".is_int?).to be true
      expect(" 515 ".is_int?).to be true
    end
  end

  describe "is_hex?" do
    it "returns true if it's a hexadecimal number" do
      expect("0x".is_hex?).to be false
      expect("x5".is_hex?).to be false
      expect("0xG".is_hex?).to be false
      expect("0xxA".is_hex?).to be false
      (0..9).each {|x| expect("0x#{x}".is_hex?).to be true }
      ('A'..'F').each {|x| expect("0x#{x}".is_hex?).to be true }
    end
  end

  describe "is_array?" do
    it "returns true if it's an array" do
      expect("1,2,3,4".is_array?).to be false
      expect("[1,2,3,4".is_array?).to be false
      expect("1,2,3,4]".is_array?).to be false
      expect("[0,1,2,3]".is_array?).to be true
      expect("[]".is_array?).to be true
      expect(" [0] ".is_array?).to be true
    end
  end

  describe "convert_to_value" do
    it "converts a float" do
      expect("5.123E5".convert_to_value).to eql 512300.0
      expect("5.123".convert_to_value).to eql 5.123
    end

    it "converts an integer" do
      expect("12345".convert_to_value).to eql 12345
      expect("0x1A".convert_to_value).to eql 0x1A
    end

    it "converts an array" do
      expect("[0,1,2,3]".convert_to_value).to eql [0,1,2,3]
    end

    it "just returns the string if something goes wrong" do
      expect("[.a,2,3]".convert_to_value).to eql "[.a,2,3]"
    end
  end

  describe "hex_to_byte_string" do
    it "converts a hex string to binary bytes" do
      expect("0xABCD".hex_to_byte_string).to eql "\xAB\xCD"
    end
  end

  describe "class_name_to_filename" do
    it "converts a class name to a filename" do
      expect("MyGreatClass".class_name_to_filename).to eql "my_great_class.rb"
    end
  end

  describe "filename_to_class_name" do
    it "converts a filename to a class name" do
      expect("my_great_class.rb".filename_to_class_name).to eql "MyGreatClass"
    end
  end

  describe "to_class" do
    it "returns the class for the string" do
      expect("String".to_class).to eql String
    end
  end
end

