# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/tools/test_runner/test'

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
class MySuite < Cosmos::TestSuite
  def setup
    Cosmos::Test.puts "#{Cosmos::Test.current_test_suite}::#{Cosmos::Test.current_test_group}::#{Cosmos::Test.current_test_case}"
  end
  def teardown
    Cosmos::Test.puts "#{Cosmos::Test.current_test_suite}::#{Cosmos::Test.current_test_group}::#{Cosmos::Test.current_test_case}"
  end
end
class MechTest < Cosmos::Test
  def setup
    # current_test and current_test_group are the same
    Cosmos::Test.puts "#{Cosmos::Test.current_test_suite}::#{Cosmos::Test.current_test}::#{Cosmos::Test.current_test_case}"
  end
  def test_mech1
    Cosmos::Test.puts "#{Cosmos::Test.current_test_suite}::#{Cosmos::Test.current_test_group}::#{Cosmos::Test.current_test_case}"
    raise "mech1_exception"
  end
  def test_mech2
    Cosmos::Test.puts "#{Cosmos::Test.current_test_suite}::#{Cosmos::Test.current_test_group}::#{Cosmos::Test.current_test_case}"
    puts "mech2_puts"
  end
  def test_mech3
    Cosmos::Test.puts "#{Cosmos::Test.current_test_suite}::#{Cosmos::Test.current_test_group}::#{Cosmos::Test.current_test_case}"
    raise Cosmos::SkipTestCase, "unimplemented"
  end
  def teardown
    Cosmos::Test.puts "#{Cosmos::Test.current_test_suite}::#{Cosmos::Test.current_test}::#{Cosmos::Test.current_test_case}"
  end
end
class ImageTest < Cosmos::Test
  def setup
    Cosmos::Test.puts "#{Cosmos::Test.current_test_suite}::#{Cosmos::Test.current_test}::#{Cosmos::Test.current_test_case}"
  end
  def test_image1
    Cosmos::Test.puts "#{Cosmos::Test.current_test_suite}::#{Cosmos::Test.current_test_group}::#{Cosmos::Test.current_test_case}"
    puts "image1_puts"
  end
  def test_image2
    Cosmos::Test.puts "#{Cosmos::Test.current_test_suite}::#{Cosmos::Test.current_test_group}::#{Cosmos::Test.current_test_case}"
    raise "image2_exception"
  end
  def test_image3
    Cosmos::Test.puts "#{Cosmos::Test.current_test_suite}::#{Cosmos::Test.current_test_group}::#{Cosmos::Test.current_test_case}"
    raise Cosmos::StopScript if $stop_script
    puts "more"
  end
  def teardown
    Cosmos::Test.puts "#{Cosmos::Test.current_test_suite}::#{Cosmos::Test.current_test}::#{Cosmos::Test.current_test_case}"
  end
end

module Cosmos
  describe TestSuite do
    before(:each) do
      @suite = MySuite.new
      $stop_script = false
    end

    describe "name" do
      it "returns the name of the suite" do
        expect(@suite.name).to eq "MySuite"
      end
    end

    describe "add_test" do
      context "with run" do
        it "runs all test cases" do
          @suite.add_test("MechTest")
          @suite.add_test("ImageTest")
          expect(@suite.tests.keys).to include(MechTest)
          expect(@suite.tests.keys).to include(ImageTest)
          results = []
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
            # where the Cosmos::Test.puts shows up in both stdout and the messages
            expect(stdout.string).to include("mech2_puts")
            expect(stdout.string).to include("test_mech2")
            expect(stdout.string).to include("image1_puts")
            expect(stdout.string).to include("test_image1")
            expect(stdout.string).to include("mech1_exception")
            expect(stdout.string).to include("image2_exception")
          end
          #                        s:s  g:s  m:1  m:2  m:3  m:t  i:s  i:1  i:2  i:3  i:t  s:t
          expect(results).to eq(%i(PASS PASS FAIL PASS SKIP PASS PASS PASS FAIL PASS PASS PASS))
          expect(messages).to eq(["MySuite::MySuite::setup\n", "MySuite::MechTest::setup\n", "MySuite::MechTest::test_mech1\n", "MySuite::MechTest::test_mech2\n", "MySuite::MechTest::test_mech3\nunimplemented\n", "MySuite::MechTest::teardown\n", "MySuite::ImageTest::setup\n", "MySuite::ImageTest::test_image1\n", "MySuite::ImageTest::test_image2\n", "MySuite::ImageTest::test_image3\n", "MySuite::ImageTest::teardown\n", "MySuite::MySuite::teardown\n"])
          expect(exceptions.map {|e| e.message }).to include("mech1_exception")
          expect(exceptions.map {|e| e.message }).to include("image2_exception")
        end
      end

      context "with run_test" do
        it "runs test cases in the specified group" do
          @suite.add_test("MechTest")
          @suite.add_test("ImageTest")
          expect(@suite.tests.keys).to include(MechTest)
          expect(@suite.tests.keys).to include(ImageTest)
          results = []
          messages = []
          exceptions = []
          capture_io do |stdout|
            $stdout.define_singleton_method(:add_stream) { |stream| }
            $stdout.define_singleton_method(:remove_stream) { |stream| }
            @suite.run_test(ImageTest) do |result|
              results << result.result
              messages << result.message
              exceptions.concat(result.exceptions) if result.exceptions
            end
          end
          expect(results).to eq(%i(PASS PASS FAIL PASS PASS))
          expect(messages).to eq(["MySuite::ImageTest::setup\n", "MySuite::ImageTest::test_image1\n", "MySuite::ImageTest::test_image2\n", "MySuite::ImageTest::test_image3\n", "MySuite::ImageTest::teardown\n"])
          expect(exceptions.map {|e| e.message }).to include("image2_exception")
        end

        it "stops upon StopScript" do
          @suite.add_test("ImageTest")
          expect(@suite.tests.keys).to include(ImageTest)
          $stop_script = true
          capture_io do |stdout|
            $stdout.define_singleton_method(:add_stream) { |stream| }
            $stdout.define_singleton_method(:remove_stream) { |stream| }
            expect { @suite.run_test(ImageTest) }.to raise_error(StopScript)
          end
        end
      end

      context "with run_test_case" do
        it "runs the specified test case" do
          @suite.add_test("MechTest")
          @suite.add_test("ImageTest")
          expect(@suite.tests.keys).to include(MechTest)
          expect(@suite.tests.keys).to include(ImageTest)
          result = nil
          capture_io do |stdout|
            $stdout.define_singleton_method(:add_stream) { |stream| }
            $stdout.define_singleton_method(:remove_stream) { |stream| }
            result = @suite.run_test_case(ImageTest, "test_image1")
          end
          expect(result.result).to eq(:PASS)
          expect(result.message).to eq("MySuite::ImageTest::test_image1\n")
          expect(result.exceptions).to be_nil
        end
      end
    end

    describe "add_test_case, add_test_setup, add_test_teardown" do
      context "with run" do
        it "runs test cases in added order" do
          # Add in weird order to verify ordering
          @suite.add_test_case("ImageTest", "test_image2")
          @suite.add_test_teardown("MechTest")
          @suite.add_test_case("MechTest", "test_mech1")
          @suite.add_test_setup("ImageTest")
          expect(@suite.tests.keys).to include(MechTest)
          expect(@suite.tests.keys).to include(ImageTest)
          messages = []
          exceptions = []
          capture_io do |stdout|
            $stdout.define_singleton_method(:add_stream) { |stream| }
            $stdout.define_singleton_method(:remove_stream) { |stream| }
            @suite.run { |result| messages << result.message; exceptions.concat(result.exceptions) if result.exceptions }
            # Note Cosmos::Test.puts shows up in both stdout and the messages
            expect(stdout.string).to include("test_mech1")
            expect(stdout.string).to include("test_image2")
            expect(stdout.string).to include("mech1_exception")
            expect(stdout.string).to include("image2_exception")
          end
          expect(messages).to eq(["MySuite::MySuite::setup\n", "MySuite::ImageTest::test_image2\n", "MySuite::MechTest::teardown\n", "MySuite::MechTest::test_mech1\n", "MySuite::ImageTest::setup\n", "MySuite::MySuite::teardown\n"])
          expect(exceptions.map {|e| e.message }).to include("mech1_exception")
          expect(exceptions.map {|e| e.message }).to include("image2_exception")
        end
      end

      context "with run_test" do
        it "runs added test cases from the specified group" do
          # Add in weird order to verify ordering
          @suite.add_test_case("ImageTest", "test_image2")
          @suite.add_test_teardown("MechTest")
          @suite.add_test_case("MechTest", "test_mech1")
          @suite.add_test_setup("ImageTest")
          expect(@suite.tests.keys).to include(MechTest)
          expect(@suite.tests.keys).to include(ImageTest)

          messages = []
          exceptions = []
          capture_io do |stdout|
            $stdout.define_singleton_method(:add_stream) { |stream| }
            $stdout.define_singleton_method(:remove_stream) { |stream| }
            @suite.run_test(ImageTest) { |result| messages << result.message; exceptions.concat(result.exceptions) if result.exceptions }
          end
          expect(messages).to eq(["MySuite::ImageTest::test_image2\n", "MySuite::ImageTest::setup\n"])
          expect(exceptions.map {|e| e.message }).to include("image2_exception")

          messages = []
          exceptions = []
          capture_io do |stdout|
            $stdout.define_singleton_method(:add_stream) { |stream| }
            $stdout.define_singleton_method(:remove_stream) { |stream| }
            @suite.run_test(MechTest) { |result| messages << result.message; exceptions.concat(result.exceptions) if result.exceptions }
          end
          expect(messages).to eq(["MySuite::MechTest::teardown\n", "MySuite::MechTest::test_mech1\n"])
          expect(exceptions.map {|e| e.message }).to include("mech1_exception")
        end
      end

      # run_test_case is no different than the add_test example
    end
  end
end
