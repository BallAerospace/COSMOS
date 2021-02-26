# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/script/suite'

# Stub out RunningScript.instance
saved_verbose = $VERBOSE; $VERBOSE = nil
class RunningScript
  def self.instance
    false
  end
end
$VERBOSE = saved_verbose

# Stub out classes for testing
$stop_script = false
class SpecSuite < Cosmos::Suite
  def setup
    Cosmos::Group.puts "#{Cosmos::Group.current_suite}::#{Cosmos::Group.current_group}::#{Cosmos::Group.current_script}"
  end
  def teardown
    Cosmos::Group.puts "#{Cosmos::Group.current_suite}::#{Cosmos::Group.current_group}::#{Cosmos::Group.current_script}"
  end
end
class MechGroup < Cosmos::Group
  def setup
    Cosmos::Group.puts "#{Cosmos::Group.current_suite}::#{Cosmos::Group.current_group}::#{Cosmos::Group.current_script}"
  end
  def test_mech1
    Cosmos::Group.puts "#{Cosmos::Group.current_suite}::#{Cosmos::Group.current_group}::#{Cosmos::Group.current_script}"
    raise "mech1_exception"
  end
  def test_mech2
    Cosmos::Group.puts "#{Cosmos::Group.current_suite}::#{Cosmos::Group.current_group}::#{Cosmos::Group.current_script}"
    puts "mech2_puts"
  end
  def test_mech3
    Cosmos::Group.puts "#{Cosmos::Group.current_suite}::#{Cosmos::Group.current_group}::#{Cosmos::Group.current_script}"
    raise Cosmos::SkipScript, "unimplemented"
  end
  def teardown
    Cosmos::Group.puts "#{Cosmos::Group.current_suite}::#{Cosmos::Group.current_group}::#{Cosmos::Group.current_script}"
  end
end
class ImageGroup < Cosmos::Group
  def setup
    Cosmos::Group.puts "#{Cosmos::Group.current_suite}::#{Cosmos::Group.current_group}::#{Cosmos::Group.current_script}"
  end
  def test_image1
    Cosmos::Group.puts "#{Cosmos::Group.current_suite}::#{Cosmos::Group.current_group}::#{Cosmos::Group.current_script}"
    puts "image1_puts"
  end
  def test_image2
    Cosmos::Group.puts "#{Cosmos::Group.current_suite}::#{Cosmos::Group.current_group}::#{Cosmos::Group.current_script}"
    raise "image2_exception"
  end
  def test_image3
    Cosmos::Group.puts "#{Cosmos::Group.current_suite}::#{Cosmos::Group.current_group}::#{Cosmos::Group.current_script}"
    # TODO: Real scripts don't have to qualify StopScript with Cosmos::
    # Why do we have to do it here?
    raise Cosmos::StopScript if $stop_script
    puts "more"
  end
  def teardown
    Cosmos::Group.puts "#{Cosmos::Group.current_suite}::#{Cosmos::Group.current_group}::#{Cosmos::Group.current_script}"
  end
end

module Cosmos
  describe Suite do
    before(:each) do
      @suite = SpecSuite.new
      $stop_script = false
    end

    describe "name" do
      it "returns the name of the suite" do
        expect(@suite.name).to eq "SpecSuite"
      end
    end

    describe "add_group" do
      context "with run" do
        it "runs all scripts" do
          @suite.add_group("MechGroup")
          @suite.add_group("ImageGroup")
          expect(@suite.scripts.keys).to include(MechGroup)
          expect(@suite.scripts.keys).to include(ImageGroup)
          results = []
          messages = []
          exceptions = []
          messages = []
          exceptions = []
          capture_io do |stdout|
            $stdout.define_singleton_method(:add_stream) { |stream| }
            $stdout.define_singleton_method(:remove_stream) { |stream| }
            @suite.run do |result|
              results << result.result
              messages << result.message
              exceptions.concat(result.exceptions) if result.exceptions
            end
            # Note the puts get captured by the stdout string but doesn't show up in messages
            # where the Cosmos::Group.puts shows up in both stdout and the messages
            expect(stdout.string).to include("mech2_puts")
            expect(stdout.string).to include("test_mech2")
            expect(stdout.string).to include("image1_puts")
            expect(stdout.string).to include("test_image1")
            expect(stdout.string).to include("mech1_exception")
            expect(stdout.string).to include("image2_exception")
          end
          expect(results).to eq(%i(PASS PASS FAIL PASS SKIP PASS PASS PASS FAIL PASS PASS PASS))
          expect(messages).to eq(["SpecSuite::SpecSuite::setup\n", "SpecSuite::MechGroup::setup\n", "SpecSuite::MechGroup::test_mech1\n", "SpecSuite::MechGroup::test_mech2\n", "SpecSuite::MechGroup::test_mech3\nunimplemented\n", "SpecSuite::MechGroup::teardown\n", "SpecSuite::ImageGroup::setup\n", "SpecSuite::ImageGroup::test_image1\n", "SpecSuite::ImageGroup::test_image2\n", "SpecSuite::ImageGroup::test_image3\n", "SpecSuite::ImageGroup::teardown\n", "SpecSuite::SpecSuite::teardown\n"])
          expect(exceptions.map {|e| e.message }).to include("mech1_exception")
          expect(exceptions.map {|e| e.message }).to include("image2_exception")
        end
      end

      context "with run_group" do
        it "runs scripts in the specified group" do
          @suite.add_group("MechGroup")
          @suite.add_group("ImageGroup")
          expect(@suite.scripts.keys).to include(MechGroup)
          expect(@suite.scripts.keys).to include(ImageGroup)
          results = []
          messages = []
          exceptions = []
          capture_io do |stdout|
            $stdout.define_singleton_method(:add_stream) { |stream| }
            $stdout.define_singleton_method(:remove_stream) { |stream| }
            @suite.run_group(ImageGroup) do |result|
              results << result.result
              messages << result.message
              exceptions.concat(result.exceptions) if result.exceptions
            end
          end
          expect(results).to eq(%i(PASS PASS FAIL PASS PASS))
          expect(messages).to eq(["SpecSuite::ImageGroup::setup\n", "SpecSuite::ImageGroup::test_image1\n", "SpecSuite::ImageGroup::test_image2\n", "SpecSuite::ImageGroup::test_image3\n", "SpecSuite::ImageGroup::teardown\n"])
          expect(exceptions.map {|e| e.message }).to include("image2_exception")
        end

        it "stops upon StopScript" do
          @suite.add_group("ImageGroup")
          expect(@suite.scripts.keys).to include(ImageGroup)
          $stop_script = true
          capture_io do |stdout|
            $stdout.define_singleton_method(:add_stream) { |stream| }
            $stdout.define_singleton_method(:remove_stream) { |stream| }
            expect { @suite.run_group(ImageGroup) }.to raise_error(StopScript)
          end
        end
      end

      context "with run_script" do
        it "runs the specified script" do
          @suite.add_group("MechGroup")
          @suite.add_group("ImageGroup")
          expect(@suite.scripts.keys).to include(MechGroup)
          expect(@suite.scripts.keys).to include(ImageGroup)
          result = nil
          capture_io do |stdout|
            $stdout.define_singleton_method(:add_stream) { |stream| }
            $stdout.define_singleton_method(:remove_stream) { |stream| }
            result = @suite.run_script(ImageGroup, "test_image1")
          end
          expect(result.message).to eq("SpecSuite::ImageGroup::test_image1\n")
          expect(result.exceptions).to be_nil
        end
      end
    end

    describe "add_script, add_group_setup, add_group_teardown" do
      context "with run" do
        it "runs scripts in added order" do
          # Add in weird order to verify ordering
          @suite.add_script("ImageGroup", "test_image2")
          @suite.add_group_teardown("MechGroup")
          @suite.add_script("MechGroup", "test_mech1")
          @suite.add_group_setup("ImageGroup")
          expect(@suite.scripts.keys).to include(MechGroup)
          expect(@suite.scripts.keys).to include(ImageGroup)
          messages = []
          exceptions = []
          capture_io do |stdout|
            $stdout.define_singleton_method(:add_stream) { |stream| }
            $stdout.define_singleton_method(:remove_stream) { |stream| }
            @suite.run { |result| messages << result.message; exceptions.concat(result.exceptions) if result.exceptions }
            # Note Cosmos::Group.puts shows up in both stdout and the messages
            expect(stdout.string).to include("test_mech1")
            expect(stdout.string).to include("test_image2")
            expect(stdout.string).to include("mech1_exception")
            expect(stdout.string).to include("image2_exception")
          end
          expect(messages).to eq(["SpecSuite::SpecSuite::setup\n", "SpecSuite::ImageGroup::test_image2\n", "SpecSuite::MechGroup::teardown\n", "SpecSuite::MechGroup::test_mech1\n", "SpecSuite::ImageGroup::setup\n", "SpecSuite::SpecSuite::teardown\n"])
          expect(exceptions.map {|e| e.message }).to include("mech1_exception")
          expect(exceptions.map {|e| e.message }).to include("image2_exception")
        end
      end

      context "with run_group" do
        it "runs added scripts from the specified group" do
          # Add in weird order to verify ordering
          @suite.add_script("ImageGroup", "test_image2")
          @suite.add_group_teardown("MechGroup")
          @suite.add_script("MechGroup", "test_mech1")
          @suite.add_group_setup("ImageGroup")
          expect(@suite.scripts.keys).to include(MechGroup)
          expect(@suite.scripts.keys).to include(ImageGroup)
          messages = []
          exceptions = []
          capture_io do |stdout|
            $stdout.define_singleton_method(:add_stream) { |stream| }
            $stdout.define_singleton_method(:remove_stream) { |stream| }
            @suite.run_group(ImageGroup) { |result| messages << result.message; exceptions.concat(result.exceptions) if result.exceptions }
          end
          expect(messages).to eq(["SpecSuite::ImageGroup::test_image2\n", "SpecSuite::ImageGroup::setup\n"])
          expect(exceptions.map {|e| e.message }).to include("image2_exception")

          messages = []
          exceptions = []
          capture_io do |stdout|
            $stdout.define_singleton_method(:add_stream) { |stream| }
            $stdout.define_singleton_method(:remove_stream) { |stream| }
            @suite.run_group(MechGroup) { |result| messages << result.message; exceptions.concat(result.exceptions) if result.exceptions }
          end
          expect(messages).to eq(["SpecSuite::MechGroup::teardown\n", "SpecSuite::MechGroup::test_mech1\n"])
          expect(exceptions.map {|e| e.message }).to include("mech1_exception")
        end
      end

      # run_script is no different than the add_group example
    end
  end
end
