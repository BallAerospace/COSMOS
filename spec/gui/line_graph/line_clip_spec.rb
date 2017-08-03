# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

if RUBY_ENGINE == 'ruby'
  require 'spec_helper'
  require 'cosmos/ext/line_graph'

  module Cosmos

    describe LineClip do

      shared_examples_for "line returned" do
        it "is not nil" do
          expect(@clipped_line).not_to be_nil
        end
      end

      shared_examples_for "no line returned" do
        it "is nil" do
          expect(@clipped_line).to be_nil
        end
      end

      shared_examples_for "not clipped" do
        it "returns the same first point" do
          expect(@clipped_line[0]).to eql(@x0)
          expect(@clipped_line[1]).to eql(@y0)
        end

        it "returns the same second point" do
          expect(@clipped_line[2]).to eql(@x1)
          expect(@clipped_line[3]).to eql(@y1)
        end

        it "indicates the first point was not clipped" do
          expect(@clipped_line[4]).to be false
        end

        it "indicates the second point was not clipped" do
          expect(@clipped_line[5]).to be false
        end
      end

      shared_examples_for "first point clipped" do
        it "returns a clipped first point" do
          expect(@xmin..@xmax).to include(@clipped_line[0])
          expect(@ymin..@ymax).to include(@clipped_line[1])
        end

        it "returns the same second point" do
          expect(@clipped_line[2]).to eql(@x1)
          expect(@clipped_line[3]).to eql(@y1)
        end

        it "indicates the first point was clipped" do
          expect(@clipped_line[4]).to be true
        end

        it "indicates the second point was not clipped" do
          expect(@clipped_line[5]).to be false
        end
      end

      shared_examples_for "second point clipped" do
        it "returns the same first point" do
          expect(@clipped_line[0]).to eql(@x0)
          expect(@clipped_line[1]).to eql(@y0)
        end

        it "returns a clipped second point" do
          expect(@xmin..@xmax).to include(@clipped_line[2])
          expect(@ymin..@ymax).to include(@clipped_line[3])
        end

        it "indicates the first point was not clipped" do
          expect(@clipped_line[4]).to be false
        end

        it "indicates the second point was clipped" do
          expect(@clipped_line[5]).to be true
        end
      end

      before(:all) do
        @xmin = -10.0
        @xmax =  10.0
        @ymin = -10.0
        @ymax =  10.0
      end

      describe "given a first point on the graph" do
        before(:all) do
          @x0 = -3.0
          @y0 =  5.0
        end

        describe "and given a second point on the graph" do
          before(:all) do
            @x1 = 3.6
            @y1 = 9.9
            @clipped_line = LineClip.line_clip(@x0, @y0, @x1, @y1, @xmin, @ymin, @xmax, @ymax)
          end

          it_should_behave_like "line returned"
          it_should_behave_like "not clipped"
        end

        describe "and given a second point off the graph to the upper left" do
          before(:all) do
            @x1 = -15.0
            @y1 = 13.0
            @clipped_line = LineClip.line_clip(@x0, @y0, @x1, @y1, @xmin, @ymin, @xmax, @ymax)
          end

          it_should_behave_like "line returned"
          it_should_behave_like "second point clipped"
        end

        describe "and given a second point off the graph to the top" do
          before(:all) do
            @x1 = 5.0
            @y1 = 180.0
            @clipped_line = LineClip.line_clip(@x0, @y0, @x1, @y1, @xmin, @ymin, @xmax, @ymax)
          end

          it_should_behave_like "line returned"
          it_should_behave_like "second point clipped"
        end

        describe "and given a second point off the graph to the upper right" do
          before(:all) do
            @x1 = 15.0
            @y1 = 13.0
            @clipped_line = LineClip.line_clip(@x0, @y0, @x1, @y1, @xmin, @ymin, @xmax, @ymax)
          end

          it_should_behave_like "line returned"
          it_should_behave_like "second point clipped"
        end

        describe "and given a second point off the graph to the right" do
          before(:all) do
            @x1 = 70.0
            @y1 = -3.0
            @clipped_line = LineClip.line_clip(@x0, @y0, @x1, @y1, @xmin, @ymin, @xmax, @ymax)
          end

          it_should_behave_like "line returned"
          it_should_behave_like "second point clipped"
        end

        describe "and given a second point off the graph to the bottom right" do
          before(:all) do
            @x1 = -15.0
            @y1 = -13.0
            @clipped_line = LineClip.line_clip(@x0, @y0, @x1, @y1, @xmin, @ymin, @xmax, @ymax)
          end

          it_should_behave_like "line returned"
          it_should_behave_like "second point clipped"
        end

        describe "and given a second point off the graph to the bottom" do
          before(:all) do
            @x1 = 0.0
            @y1 = 13.57
            @clipped_line = LineClip.line_clip(@x0, @y0, @x1, @y1, @xmin, @ymin, @xmax, @ymax)
          end

          it_should_behave_like "line returned"
          it_should_behave_like "second point clipped"
        end

        describe "and given a second point off the graph to the bottom left" do
          before(:all) do
            @x1 = -150.0
            @y1 = -150.0
            @clipped_line = LineClip.line_clip(@x0, @y0, @x1, @y1, @xmin, @ymin, @xmax, @ymax)
          end

          it_should_behave_like "line returned"
          it_should_behave_like "second point clipped"
        end

        describe "and given a second point off the graph to the left" do
          before(:all) do
            @x1 = -20.0
            @y1 = 3.0
            @clipped_line = LineClip.line_clip(@x0, @y0, @x1, @y1, @xmin, @ymin, @xmax, @ymax)
          end

          it_should_behave_like "line returned"
          it_should_behave_like "second point clipped"
        end
      end

      describe "given a second point on the graph" do
        before(:all) do
          @x1 =  3.2
          @y1 = -9.9
        end

        describe "and given a first point on the graph" do
          before(:all) do
            @x0 = 3.6
            @y0 = 9.9
            @clipped_line = LineClip.line_clip(@x0, @y0, @x1, @y1, @xmin, @ymin, @xmax, @ymax)
          end

          it_should_behave_like "line returned"
          it_should_behave_like "not clipped"
        end

        describe "and given a first point off the graph to the upper left" do
          before(:all) do
            @x0 = -15.0
            @y0 = 13.0
            @clipped_line = LineClip.line_clip(@x0, @y0, @x1, @y1, @xmin, @ymin, @xmax, @ymax)
          end

          it_should_behave_like "line returned"
          it_should_behave_like "first point clipped"
        end

        describe "and given a first point off the graph to the top" do
          before(:all) do
            @x0 = 5.0
            @y0 = 180.0
            @clipped_line = LineClip.line_clip(@x0, @y0, @x1, @y1, @xmin, @ymin, @xmax, @ymax)
          end

          it_should_behave_like "line returned"
          it_should_behave_like "first point clipped"
        end

        describe "and given a first point off the graph to the upper right" do
          before(:all) do
            @x0 = 15.0
            @y0 = 13.0
            @clipped_line = LineClip.line_clip(@x0, @y0, @x1, @y1, @xmin, @ymin, @xmax, @ymax)
          end

          it_should_behave_like "line returned"
          it_should_behave_like "first point clipped"
        end

        describe "and given a first point off the graph to the right" do
          before(:all) do
            @x0 = 70.0
            @y0 = -3.0
            @clipped_line = LineClip.line_clip(@x0, @y0, @x1, @y1, @xmin, @ymin, @xmax, @ymax)
          end

          it_should_behave_like "line returned"
          it_should_behave_like "first point clipped"
        end

        describe "and given a first point off the graph to the bottom right" do
          before(:all) do
            @x0 = -15.0
            @y0 = -13.0
            @clipped_line = LineClip.line_clip(@x0, @y0, @x1, @y1, @xmin, @ymin, @xmax, @ymax)
          end

          it_should_behave_like "line returned"
          it_should_behave_like "first point clipped"
        end

        describe "and given a first point off the graph to the bottom" do
          before(:all) do
            @x0 = 0.0
            @y0 = 13.57
            @clipped_line = LineClip.line_clip(@x0, @y0, @x1, @y1, @xmin, @ymin, @xmax, @ymax)
          end

          it_should_behave_like "line returned"
          it_should_behave_like "first point clipped"
        end

        describe "and given a first point off the graph to the bottom left" do
          before(:all) do
            @x0 = -150.0
            @y0 = -150.0
            @clipped_line = LineClip.line_clip(@x0, @y0, @x1, @y1, @xmin, @ymin, @xmax, @ymax)
          end

          it_should_behave_like "line returned"
          it_should_behave_like "first point clipped"
        end

        describe "and given a first point off the graph to the left" do
          before(:all) do
            @x0 = -20.0
            @y0 = 3.0
            @clipped_line = LineClip.line_clip(@x0, @y0, @x1, @y1, @xmin, @ymin, @xmax, @ymax)
          end

          it_should_behave_like "line returned"
          it_should_behave_like "first point clipped"
        end
      end

      describe "given a both points off the graph" do
        before(:all) do
          @x0 =  15.0
          @y0 = -15.0
          @x1 =  13.2
          @y1 = -9.9
          @clipped_line = LineClip.line_clip(@x0, @y0, @x1, @y1, @xmin, @ymin, @xmax, @ymax)
        end

        it_should_behave_like "no line returned"
      end
    end

  end # module Cosmos
end
