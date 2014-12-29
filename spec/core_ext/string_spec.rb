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

    it "should use 1 byte words" do
      @data.formatted.split("\n")[0].should eql "00000000: 1A 1B 1C 1D 1E 1F 20 21 22 23 24 25 26 27 28 29         !\"#\$%&\'\(\)"
      @data.formatted.split("\n")[1].should eql "00000010: 2A 2B 2C 2D 2E 2F                                *+,-./          "
    end

    it "should use 2 byte words" do
      @data.formatted(2, 8).should match "00000000: 1A1B 1C1D 1E1F" # ...
      @data.formatted(2, 8).should match "00000010: 2A2B 2C2D 2E2F"
    end

    it "should change the word separator" do
      @data.formatted(2, 4, '_').should match "00000000: 1A1B_1C1D_1E1F_2021"
      @data.formatted(2, 4, '_').should match "00000008: 2223_2425_2627_2829"
      @data.formatted(2, 4, '_').should match "00000010: 2A2B_2C2D_2E2F"
    end

    it "should indent the lines" do
      @data.formatted(1, 16, ' ', 4).should match "    00000000: 1A 1B 1C 1D"
    end

    it "should not show the address" do
      @data.formatted(1, 16, ' ', 0, false).should match "1A 1B 1C 1D"
    end

    it "should change the address separator" do
      @data.formatted(1, 16, ' ', 0, true, '= ').should match "00000000= 1A 1B 1C 1D"
    end

    it "should not show the ASCII" do
      @data.formatted(1,16,'',0,true,'',true).should match '29         !"#\$%&\'()'
      @data.formatted(1,16,'',0,true,'',false).should_not match '29         !"#\$%&\'()'
    end

    it "should change the ASCII separator" do
      @data.formatted(1,16,'',0,true,'',true,'__').should match '29__       !"#\$%&\'()'
    end

    it "should change the ASCII unprintable character" do
      @data.formatted(1,16,'',0,true,'',true,'__','x').should match '29__xxxxxx !"#\$%&\'()'
    end

    it "should change the line separator" do
      @data.formatted(1,16,' ',0,true,': ',true,'  ',' ', '~').split("~")[0].should eql "00000000: 1A 1B 1C 1D 1E 1F 20 21 22 23 24 25 26 27 28 29         !\"#\$%&\'\(\)"
      @data.formatted(1,16,' ',0,true,': ',true,'  ',' ', '~').split("~")[1].should eql "00000010: 2A 2B 2C 2D 2E 2F                                *+,-./          "
    end
  end

  describe "simple_formatted" do
    before(:each) do
      @data = []
      (26..47).each {|x| @data << x }
      @data = @data.pack('C*')
    end

    it "should format the data" do
      @data.simple_formatted.should eql "1A1B1C1D1E1F202122232425262728292A2B2C2D2E2F"
    end
  end

  describe "remove_line" do
    it "should remove the specified line" do
      test = "this\nis\na\ntest"
      test.remove_line(1).should eql "is\na\ntest"
      test.should eql "this\nis\na\ntest"
    end

    it "should split on the given separator" do
      test = "thisXisXaXtest"
      test.remove_line(4,'X').should eql "thisXisXaX"
    end

    it "should do nothing if the line number isn't found" do
      test = "thisXisXaXtest"
      test.remove_line(5,'X').should eql "thisXisXaXtest"
    end
  end

  describe "num_lines" do
    it "should count the number of newlines" do
      test = "this\nis\na\ntest"
      test.num_lines.should eql 4
    end

    it "should not count trailing newlines" do
      test = "this\nis\na\ntest\n"
      test.num_lines.should eql 4
    end
  end

  describe "remove_quotes" do
    context "with single quotes" do
      it "should remove leading and trailing single quotes" do
        test = "'string'"
        test.remove_quotes.should eql "string"
      end

      it "should not remove interior" do
        test = "can't"
        test.remove_quotes.should eql "can't"
      end
    end

    context "with double quotes" do
      it "should remove leading and trailing" do
        test = '"string"'
        test.remove_quotes.should eql "string"
      end

      it "should not remove interior" do
        test = 'say("HI")'
        test.remove_quotes.should eql 'say("HI")'
      end
    end
  end

  describe "is_float?" do
    it "should return true if it's a float" do
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
    it "should return true if it's an integer" do
      expect("hi".is_int?).to be false
      expect("hi 5".is_int?).to be false
      expect("5 hi".is_int?).to be false
      expect("515.0".is_int?).to be false
      expect("515".is_int?).to be true
      expect(" 515 ".is_int?).to be true
    end
  end

  describe "is_hex?" do
    it "should return true if it's a hexadecimal number" do
      expect("0x".is_hex?).to be false
      expect("x5".is_hex?).to be false
      expect("0xG".is_hex?).to be false
      expect("0xxA".is_hex?).to be false
      (0..9).each {|x| expect("0x#{x}".is_hex?).to be true }
      ('A'..'F').each {|x| expect("0x#{x}".is_hex?).to be true }
    end
  end

  describe "is_array?" do
    it "should return true if it's an array" do
      expect("1,2,3,4".is_array?).to be false
      expect("[1,2,3,4".is_array?).to be false
      expect("1,2,3,4]".is_array?).to be false
      expect("[0,1,2,3]".is_array?).to be true
      expect("[]".is_array?).to be true
      expect(" [0] ".is_array?).to be true
    end
  end

  describe "convert_to_value" do
    it "should convert a float" do
      "5.123E5".convert_to_value.should eql 512300.0
      "5.123".convert_to_value.should eql 5.123
    end

    it "should convert an integer" do
      "12345".convert_to_value.should eql 12345
      "0x1A".convert_to_value.should eql 0x1A
    end

    it "should convert an array" do
      "[0,1,2,3]".convert_to_value.should eql [0,1,2,3]
    end
  end

  describe "hex_to_byte_string" do
    it "should convert a hex string to binary bytes" do
      "0xABCD".hex_to_byte_string.should eql "\xAB\xCD"
    end
  end

  describe "class_name_to_filename" do
    it "should convert a class name to a filename" do
      "MyGreatClass".class_name_to_filename.should eql "my_great_class.rb"
    end
  end

  describe "filename_to_class_name" do
    it "should convert a filename to a class name" do
      "my_great_class.rb".filename_to_class_name.should eql "MyGreatClass"
    end
  end

  describe "to_class" do
    it "should return the class for the string" do
      "String".to_class.should eql String
    end
  end
end

