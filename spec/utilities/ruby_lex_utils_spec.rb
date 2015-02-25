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
      it "detects the begin keyword" do
        expect(@lex.contains_begin?("  begin  ")).to be_truthy
        expect(@lex.contains_begin?("  begin # asdf  ")).to be_truthy
      end
    end

    describe "contains_keyword?" do
      it "detects the ruby keywords" do
        expect(@lex.contains_keyword?("if something")).to be_truthy
        expect(@lex.contains_keyword?("obj.method = something")).to be_falsey
      end
    end

    describe "contains_block_beginning?" do
      it "detects block beginning keywords" do
        expect(@lex.contains_block_beginning?("do")).to be_truthy
        expect(@lex.contains_block_beginning?("[].each {")).to be_truthy
        expect(@lex.contains_block_beginning?("begin")).to be_truthy
      end
    end

    describe "remove_comments" do
      it "removes comments" do
text = <<DOC
# This is a comment
blah = 5 # Inline comment
# Another
DOC
        expect(@lex.remove_comments(text)).to eql "\nblah = 5 \n\n"
      end
    end

    describe "each_lexed_segment" do
      it "yields each segment" do
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

      it "yields each segment" do
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

