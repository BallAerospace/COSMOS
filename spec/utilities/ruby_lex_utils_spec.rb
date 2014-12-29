# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require "spec_helper"
require "cosmos/utilities/ruby_lex_utils"

module Cosmos
  describe RubyLexUtils do
    before(:each) do
      @lex = RubyLexUtils.new
    end

    describe "contains_begin?" do
      it "should detect the begin keyword" do
        @lex.contains_begin?("  begin  ").should be_truthy
        @lex.contains_begin?("  begin # asdf  ").should be_truthy
      end
    end

    describe "contains_keyword?" do
      it "should detect the ruby keywords" do
        @lex.contains_keyword?("if something").should be_truthy
        @lex.contains_keyword?("obj.method = something").should be_falsey
      end
    end

    describe "contains_block_beginning?" do
      it "should detect block beginning keywords" do
        @lex.contains_block_beginning?("do").should be_truthy
        @lex.contains_block_beginning?("[].each {").should be_truthy
        @lex.contains_block_beginning?("begin").should be_truthy
      end
    end

    describe "remove_comments" do
      it "should remove comments" do
text = <<DOC
# This is a comment
blah = 5 # Inline comment
# Another
DOC
        @lex.remove_comments(text).should eql "\nblah = 5 \n\n"
      end
    end

    describe "each_lexed_segment" do
      it "should yield each segment" do
text = <<DOC
begin
  x = 0
end
DOC
        expect { |b| @lex.each_lexed_segment(text, &b) }.to yield_successive_args(
          ["begin\n",false,0,1],  # can't instrument begin
          ["  x = 0\n",true,0,2],
          ["end\n",false,nil,3])  # can't instrument end
      end

      it "should yield each segment" do
text = <<DOC

if x
y
else
z
end
DOC
        expect { |b| @lex.each_lexed_segment(text, &b) }.to yield_successive_args(
          ["\n",true,nil,1],
          ["if x\n",false,nil,2], # can't instrument if
          ["y\n",true,nil,3],
          ["else\n",false,nil,4], # can't instrument else
          ["z\n",true,nil,5],
          ["end\n",false,nil,6])  # can't instrument end
      end
    end
  end
end

