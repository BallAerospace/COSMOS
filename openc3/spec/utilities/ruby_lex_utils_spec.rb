# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require "spec_helper"
require "openc3/utilities/ruby_lex_utils"

module OpenC3
  describe RubyLexUtils do
    before(:each) do
      @lex = RubyLexUtils.new
    end

    describe "contains_begin?" do
      it "detects the begin keyword" do
        expect(@lex.contains_begin?("  begin  ")).to be true
        expect(@lex.contains_begin?("  begin # asdf  ")).to be true
      end
    end

    describe "contains_keyword?" do
      it "detects the ruby keywords" do
        expect(@lex.contains_keyword?("if something")).to be true
        expect(@lex.contains_keyword?("obj.method = something")).to be false
      end
    end

    describe "contains_block_beginning?" do
      it "detects block beginning keywords" do
        expect(@lex.contains_block_beginning?("do")).to be true
        expect(@lex.contains_block_beginning?("[].each {")).to be true
        expect(@lex.contains_block_beginning?("begin")).to be true
      end
    end

    describe "remove_comments" do
      it "removes comments" do
        text = <<~DOC
          # This is a comment
          blah = 5 # Inline comment
          # Another
        DOC
        expect(@lex.remove_comments(text)).to eql "\nblah = 5 \n\n"
      end
    end

    describe "each_lexed_segment" do
      it "yields each segment" do
        text = <<~DOC
          begin
            x = 0
          end
        DOC
        expect { |b| @lex.each_lexed_segment(text, &b) }.to yield_successive_args(
          ["begin\n", false, true, 1], # can't instrument begin
          ["  x = 0\n", true, true, 2],
          ["end\n", false, false, 3]
        ) # can't instrument end
      end

      it "handles multiple begins" do
        text = <<~DOC
          z = 5
          begin
            a = 0
            begin
              x = 0
            rescue
              x = 1
            end
          end
        DOC
        expect { |b| @lex.each_lexed_segment(text, &b) }.to yield_successive_args(
          ["z = 5\n", true, false, 1],
          ["begin\n", false, true, 2], # can't instrument begin
          ["  a = 0\n", true, true, 3],
          ["  begin\n", false, true, 4],
          ["    x = 0\n", true, true, 5],
          ["  rescue\n", false, true, 6],
          ["    x = 1\n", true, true, 7],
          ["  end\n", false, true, 8],
          ["end\n", false, false, 9]
        ) # can't instrument end
      end

      it "handles multiline segments" do
        text = <<~DOC
          a = [10,
          11,
          12,
          13,
          14]
        DOC
        expect { |b| @lex.each_lexed_segment(text, &b) }.to yield_successive_args(
          ["a = [10,\n11,\n12,\n13,\n14]\n", true, false, 1]
        )
      end

      it "handles complex hash segments" do
        text = <<~DOC
          { :X1 => 1,
            :X2 => 2
          }.each {|x, y| puts x}
        DOC
        expect { |b| @lex.each_lexed_segment(text, &b) }.to yield_successive_args(
          ["{ :X1 => 1,\n  :X2 => 2\n", false, false, 1],
          ["}.each {|x, y| puts x}\n", false, false, 3]
        )
      end

      it "yields each segment" do
        text = <<~DOC

                    if x
                    y
                    else
                    z
                    end
        DOC
        expect { |b| @lex.each_lexed_segment(text, &b) }.to yield_successive_args(
          ["\n", true, false, 1],
          ["if x\n", false, false, 2], # can't instrument if
          ["y\n", true, false, 3],
          ["else\n", false, false, 4], # can't instrument else
          ["z\n", true, false, 5],
          ["end\n", false, false, 6]
        )  # can't instrument end
      end
    end
  end
end
