# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos'
require 'cosmos/config/config_parser'
require 'tempfile'

module Cosmos

  describe ConfigParser do
    before(:each) do
      @cp = ConfigParser.new
      ConfigParser.message_callback = nil
      ConfigParser.progress_callback = nil
    end

    describe "parse_file" do
      it "should yield keyword, parameters to the block" do
        tf = Tempfile.new('unittest')
        line = "KEYWORD PARAM1 PARAM2 'PARAM 3'"
        tf.puts line
        tf.close

        @cp.parse_file(tf.path) do |keyword, params|
          keyword.should eql "KEYWORD"
          params.should include('PARAM1','PARAM2','PARAM 3')
          @cp.line.should eql line
          @cp.line_number.should eql 1
        end
        tf.unlink
      end

      it "should handle Ruby string interpolation" do
        tf = Tempfile.new('unittest')
        tf.puts 'KEYWORD1 #{var} PARAM1'
        tf.puts 'KEYWORD2 PARAM1 #Comment'
        tf.close

        results = {}
        @cp.parse_file(tf.path) do |keyword, params|
          results[keyword] = params
        end

        results.keys.should eql %w(KEYWORD1 KEYWORD2)
        results["KEYWORD1"].should eql %w(#{var} PARAM1)
        results["KEYWORD2"].should eql %w(PARAM1)
        tf.unlink
      end

      it "should optionally not remove quotes" do
        tf = Tempfile.new('unittest')
        line = "KEYWORD PARAM1 PARAM2 'PARAM 3'"
        tf.puts line
        tf.close

        @cp.parse_file(tf.path, false, false) do |keyword, params|
          keyword.should eql "KEYWORD"
          params.should include('PARAM1','PARAM2',"'PARAM 3'")
          @cp.line.should eql line
          @cp.line_number.should eql 1
        end
        tf.unlink
      end

      it "should handle inline line continuations" do
        tf = Tempfile.new('unittest')
        tf.puts "KEYWORD PARAM1 & PARAM2"
        tf.close

        @cp.parse_file(tf.path) do |keyword, params|
          keyword.should eql "KEYWORD"
          params.should eql %w(PARAM1 & PARAM2)
          @cp.line.should eql "KEYWORD PARAM1 & PARAM2"
          @cp.line_number.should eql 1
        end
        tf.unlink
      end

      it "should handle line continuations as EOL" do
        tf = Tempfile.new('unittest')
        tf.puts "KEYWORD PARAM1 &"
        tf.puts "  PARAM2 'PARAM 3'"
        tf.close

        @cp.parse_file(tf.path) do |keyword, params|
          keyword.should eql "KEYWORD"
          params.should include('PARAM1','PARAM2','PARAM 3')
          @cp.line.should eql "KEYWORD PARAM1 PARAM2 'PARAM 3'"
          @cp.line_number.should eql 2
        end

        @cp.parse_file(tf.path, false, false) do |keyword, params|
          keyword.should eql "KEYWORD"
          params.should include('PARAM1','PARAM2',"'PARAM 3'")
          @cp.line.should eql "KEYWORD PARAM1 PARAM2 'PARAM 3'"
          @cp.line_number.should eql 2
        end
        tf.unlink
      end

      it "should optionally yield comment lines" do
        tf = Tempfile.new('unittest')
        tf.puts "KEYWORD1 PARAM1"
        tf.puts "# This is a comment"
        tf.puts "KEYWORD2 PARAM1"
        tf.close

        lines = []
        @cp.parse_file(tf.path, true) do |keyword, params|
          lines << @cp.line
        end
        lines.should include("# This is a comment")
        tf.unlink
      end

      it "should callback for messages" do
        tf = Tempfile.new('unittest')
        line = "KEYWORD PARAM1 PARAM2 'PARAM 3'"
        tf.puts line
        tf.close

        msg_callback = double(:call => true)
        expect(msg_callback).to receive(:call).once.with(/Parsing .* bytes of #{tf.path}/)

        ConfigParser.message_callback = msg_callback
        @cp.parse_file(tf.path) do |keyword, params|
          keyword.should eql "KEYWORD"
          params.should include('PARAM1','PARAM2','PARAM 3')
          @cp.line.should eql line
          @cp.line_number.should eql 1
        end
        tf.unlink
      end

      it "should callback for percent done" do
        tf = Tempfile.new('unittest')
        # Callback is made at beginning, every 10 lines, and at the end
        15.times { tf.puts "KEYWORD PARAM" }
        tf.close

        msg_callback = double(:call => true)
        done_callback = double(:call => true)
        expect(done_callback).to receive(:call).with(0.0)
        expect(done_callback).to receive(:call).with(0.6)
        expect(done_callback).to receive(:call).with(1.0)

        ConfigParser.message_callback = msg_callback
        ConfigParser.progress_callback = done_callback
        @cp.parse_file(tf.path) {|k,p|}
        tf.unlink
      end
    end

    describe "verify_num_parameters" do
      it "should verify the minimum number of parameters" do
        tf = Tempfile.new('unittest')
        line = "KEYWORD"
        tf.puts line
        tf.close

        @cp.parse_file(tf.path) do |keyword, params|
          keyword.should eql "KEYWORD"
          expect { @cp.verify_num_parameters(1, 1) }.to raise_error(ConfigParser::Error, "Not enough parameters for KEYWORD.")
        end
        tf.unlink
      end

      it "should verify the maximum number of parameters" do
        tf = Tempfile.new('unittest')
        line = "KEYWORD PARAM1 PARAM2"
        tf.puts line
        tf.close

        @cp.parse_file(tf.path) do |keyword, params|
          keyword.should eql "KEYWORD"
          expect { @cp.verify_num_parameters(1, 1) }.to raise_error(ConfigParser::Error, "Too many parameters for KEYWORD.")
        end
        tf.unlink
      end
    end

    describe "error" do
      it "should return an Error" do
        tf = Tempfile.new('unittest')
        line = "KEYWORD"
        tf.puts line
        tf.close

        @cp.parse_file(tf.path) do |keyword, params|
          error = @cp.error("Hello")
          error.message.should eql "Hello"
          error.keyword.should eql "KEYWORD"
          error.filename.should eql tf.path
        end
        tf.unlink
      end
    end

    describe "self.handle_nil" do
      it "should convert 'NIL' and 'NULL' to nil" do
        ConfigParser.handle_nil('NIL').should be_nil
        ConfigParser.handle_nil('NULL').should be_nil
        ConfigParser.handle_nil('nil').should be_nil
        ConfigParser.handle_nil('null').should be_nil
        ConfigParser.handle_nil('').should be_nil
      end

      it "should return nil with nil" do
        ConfigParser.handle_nil(nil).should be_nil
      end

      it "should return values that don't convert" do
        ConfigParser.handle_nil("HI").should eql "HI"
        ConfigParser.handle_nil(5.0).should eql 5.0
      end

      #it "should complain if it can't convert" do
      #  expect { ConfigParser.handle_nil(0) }.to raise_error(ArgumentError, "Value is not nil: 0")
      #  expect { ConfigParser.handle_nil(false) }.to raise_error(ArgumentError, "Value is not nil: false")
      #end
    end

    describe "self.handle_true_false" do
      it "should convert 'TRUE' and 'FALSE'" do
        expect(ConfigParser.handle_true_false('TRUE')).to be true
        expect(ConfigParser.handle_true_false('FALSE')).to be false
        expect(ConfigParser.handle_true_false('true')).to be true
        expect(ConfigParser.handle_true_false('false')).to be false
      end

      it "should pass through true and false" do
        expect(ConfigParser.handle_true_false(true)).to be true
        expect(ConfigParser.handle_true_false(false)).to be false
      end

      it "should return values that don't convert" do
        ConfigParser.handle_true_false("HI").should eql "HI"
        ConfigParser.handle_true_false(5.0).should eql 5.0
      end

      #it "should complain if it can't convert" do
      #  expect { ConfigParser.handle_true_false(0) }.to raise_error(ArgumentError, "Value neither true or false: 0")
      #  expect { ConfigParser.handle_true_false(nil) }.to raise_error(ArgumentError, "Value neither true or false: ")
      #end
    end

    describe "self.handle_true_false_nil" do
      it "should convert 'NIL' and 'NULL' to nil" do
        ConfigParser.handle_true_false_nil('NIL').should be_nil
        ConfigParser.handle_true_false_nil('NULL').should be_nil
        ConfigParser.handle_true_false_nil('nil').should be_nil
        ConfigParser.handle_true_false_nil('null').should be_nil
        ConfigParser.handle_true_false_nil('').should be_nil
      end

      it "should return nil with nil" do
        ConfigParser.handle_true_false_nil(nil).should be_nil
      end

      it "should convert 'TRUE' and 'FALSE'" do
        expect(ConfigParser.handle_true_false_nil('TRUE')).to be true
        expect(ConfigParser.handle_true_false_nil('FALSE')).to be false
        expect(ConfigParser.handle_true_false_nil('true')).to be true
        expect(ConfigParser.handle_true_false_nil('false')).to be false
      end

      it "should pass through true and false" do
        expect(ConfigParser.handle_true_false_nil(true)).to be true
        expect(ConfigParser.handle_true_false_nil(false)).to be false
      end

      it "should return values that don't convert" do
        ConfigParser.handle_true_false("HI").should eql "HI"
        ConfigParser.handle_true_false(5.0).should eql 5.0
      end

      #it "should complain if it can't convert" do
      #  expect { ConfigParser.handle_true_false_nil(0) }.to raise_error(ArgumentError, "Value neither true, false, or nil: 0")
      #  expect { ConfigParser.handle_true_false_nil(1) }.to raise_error(ArgumentError, "Value neither true, false, or nil: 1")
      #end
    end

    describe "self.handle_defined_constants" do
      it "should convert string constants to numbers" do
        [8,16,32,64].each do |val|
          # Unsigned
          ConfigParser.handle_defined_constants("MIN_UINT#{val}").should eql 0
          ConfigParser.handle_defined_constants("MAX_UINT#{val}").should eql (2**val - 1)
          # Signed
          ConfigParser.handle_defined_constants("MIN_INT#{val}").should eql -((2**val) / 2)
          ConfigParser.handle_defined_constants("MAX_INT#{val}").should eql ((2**val) / 2 - 1)
        end
        # Float
        ConfigParser.handle_defined_constants("MIN_FLOAT32").should be <= -3.4 * 10**38
        ConfigParser.handle_defined_constants("MAX_FLOAT32").should be >= 3.4 * 10**38
        ConfigParser.handle_defined_constants("MIN_FLOAT64").should eql -Float::MAX
        ConfigParser.handle_defined_constants("MAX_FLOAT64").should eql Float::MAX
        ConfigParser.handle_defined_constants("POS_INFINITY").should eql Float::INFINITY
        ConfigParser.handle_defined_constants("NEG_INFINITY").should eql -Float::INFINITY
      end

      it "should complain about undefined strings" do
        expect { ConfigParser.handle_defined_constants("TRUE") }.to raise_error(ArgumentError, "Could not convert constant: TRUE")
      end

      it "should pass through numbers" do
        ConfigParser.handle_defined_constants(0).should eql 0
        ConfigParser.handle_defined_constants(0.0).should eql 0.0
      end
    end

  end
end

