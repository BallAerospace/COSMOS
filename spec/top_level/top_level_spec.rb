# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/top_level'
require 'fileutils'

describe "HazardousError" do
  it "should have accessors" do
    error = HazardousError.new
    error.target_name = "TGT"
    error.target_name.should eql "TGT"
    error.cmd_name = "CMD"
    error.cmd_name.should eql "CMD"
    error.cmd_params = ["ID","BLAH"]
    error.cmd_params.should eql ["ID","BLAH"]
    error.hazardous_description = "Description"
    error.hazardous_description.should eql "Description"
  end
end

module Cosmos
  def self.cleanup_exceptions
    # Delete the 'exception' files
    Dir[File.join(System.paths['LOGS'], '*')].each {|file| FileUtils.rm_f file }
    Dir[File.join(File.dirname(__FILE__),"*exception.txt")].each {|file| FileUtils.rm_f file }
  end

  describe "FatalError" do
    it "should be a StandardError" do
      FatalError.new.should be_a StandardError
    end
  end

  describe "self.disable_warnings" do
    it "should disable Ruby warnings" do
      stderr = StringIO.new('', 'r+')
      $stderr = stderr
      save = Cosmos::PATH
      Cosmos::PATH = "HI"
      stderr.string.should match /warning\: already initialized constant/
      Cosmos::PATH = save

      save_mutex = Cosmos::COSMOS_MUTEX
      Cosmos.disable_warnings do
        Cosmos::COSMOS_MUTEX = "HI"
        Cosmos::COSMOS_MUTEX = save_mutex
      end
      stderr.string.should_not match "warning: already initialized constant COSMOS_MUTEX"
      $stderr = STDERR
    end
  end

  describe "self.define_user_path" do
    after(:each) do
      Cosmos.disable_warnings do
        Cosmos.const_set(:USERPATH, DEFAULT_USERPATH)
      end
      ENV.delete('COSMOS_USERPATH')
    end

    it "should be initially set" do
      Cosmos::USERPATH.should_not be_nil
    end

    context "when searching for userpath.txt" do
      it "should giveup if it can't be found" do
        old = Cosmos::USERPATH
        Cosmos.define_user_path(Dir.home)
        Cosmos::USERPATH.should eql old
      end

      it "should set the path to where userpath.txt is found" do
        ENV.delete('COSMOS_USERPATH')
        old = Cosmos::USERPATH
        old.should_not eql File.dirname(__FILE__)
        File.open(File.join(File.dirname(__FILE__), 'userpath.txt'),'w') {|f| f.puts '' }
        Cosmos.define_user_path(File.dirname(__FILE__))
        Cosmos::USERPATH.should eql File.dirname(__FILE__)
        File.delete(File.join(File.dirname(__FILE__), 'userpath.txt'))
      end
    end
  end

  describe "self.add_to_search_path" do
    it "should add a directory to the Ruby search path" do
      if Kernel.is_windows?
        $:.should_not include("C:/test/path")
        Cosmos.add_to_search_path("C:/test/path")
        $:.should include("C:/test/path")
      end
    end
  end

  describe "self.marshal_dump, self.marshal_load" do
    after(:each) do
      Cosmos.disable_warnings do
        Cosmos.const_set(:USERPATH, DEFAULT_USERPATH)
      end
      ENV.delete('COSMOS_USERPATH')
    end

    it "should dump and load a Ruby object" do
      capture_io do |stdout|
        # Configure the user path to be local
        ENV['COSMOS_USERPATH'] = File.dirname(__FILE__)
        Cosmos.define_user_path

        array = [1,2,3,4]
        Cosmos.marshal_dump('marshal_test', array)
        array_load = Cosmos.marshal_load('marshal_test')
        File.exist?(File.join(Cosmos::USERPATH,'marshal_test')).should be_truthy
        array.should eql array_load
        File.delete(File.join(Cosmos::USERPATH,'marshal_test'))
      end
    end

    it "should rescue marshal dump errors" do
      capture_io do |stdout|
        system_exit_count = $system_exit_count
        Cosmos.marshal_dump('marshal_test', Proc.new { '' })
        $system_exit_count.should be > system_exit_count
        stdout.string.should match "no _dump_data is defined for class Proc"
      end
      Cosmos.cleanup_exceptions()
    end

    it "should rescue marshal load errors" do
      # Attempt to load something that doesn't exist
      Cosmos.marshal_load('blah').should be_nil

      # Attempt to load something that doesn't have the marshal header
      File.open(File.join(Cosmos::USERPATH,'marshal_test'),'wb') {|f| f.puts "marshal!" }
      Cosmos.marshal_load('marshal_test').should be_nil

      # Attempt to load something that has a bad marshal
      File.open(File.join(Cosmos::USERPATH,'marshal_test'),'wb') do |file|
        file.write(Cosmos::COSMOS_MARSHAL_HEADER)
        file.write("\x00\x01")
      end

      capture_io do |stdout|
        Cosmos.marshal_load('marshal_test')
        stdout.string.should match "Marshal load failed with exception"
      end
      Cosmos.cleanup_exceptions()
    end
  end

  describe "run_process" do
    it "should return a Thread" do
      if Kernel.is_windows?
        capture_io do |stdout|
          thread = Cosmos.run_process("ping 192.0.0.234 -n 1 -w 1000 > nul")
          sleep 0.1
          thread.should be_a Thread
          thread.alive?.should be_truthy
          sleep 2
          thread.alive?.should be_falsey
        end
      end
    end
  end

  describe "run_process_check_output" do
    it "should execute a command while capturing output" do
      if Kernel.is_windows?
        require 'Qt'
        allow(Qt::Application).to receive(:instance).and_return(nil)
        output = ''
        allow(Logger).to receive(:error) {|str| output = str}
        thread = Cosmos.run_process_check_output("ping 192.0.0.234 -n 1 -w 1000")
        sleep 0.1 while thread.alive?
        output.should match "Pinging 192.0.0.234"
      end
    end
  end

  describe "md5_files" do
    it "should calculate a MD5 sum across files" do
      File.open(File.join(Cosmos::USERPATH,'test1.txt'),'w') {|f| f.puts "test1" }
      File.open(File.join(Cosmos::USERPATH,'test2.txt'),'w') {|f| f.puts "test2" }
      digest = Cosmos.md5_files(["test1.txt", "test2.txt"])
      digest.digest.length.should be 16
      digest.hexdigest.should eql 'e51dfbea83de9c7e6b49560089d8a170'
      File.delete(File.join(Cosmos::USERPATH, 'test1.txt'))
      File.delete(File.join(Cosmos::USERPATH, 'test2.txt'))
    end
  end

  describe "create_log_file" do
    it "should create a log file even if System LOGS doesn't exist" do
      filename = Cosmos.create_log_file('test', 'X:/directory/which/does/not/exit')
      File.exist?(filename).should be_truthy
      File.delete(filename)

      Cosmos.set_working_dir do
        # Move the defaults output dir out of the way for this test
        FileUtils.mv('outputs', 'outputs_bak')

        # Create a logs directory as the first order backup
        FileUtils.mkdir('logs')
        filename = Cosmos.create_log_file('test', 'X:/directory/which/does/not/exit')
        File.exist?(filename).should be_truthy
        File.delete(filename)

        # Delete logs and see if we still get a log file
        FileUtils.rm_rf('logs')
        filename = Cosmos.create_log_file('test', 'X:/directory/which/does/not/exit')
        File.exist?(filename).should be_truthy
        File.delete(filename)

        # Restore outputs
        FileUtils.mv('outputs_bak', 'outputs')
      end
    end
  end

  describe "write_exception_file" do
    it "should write an exception file" do
      file = Cosmos.write_exception_file(nil, 'test1_exception', File.dirname(__FILE__))
      File.exist?(file).should be_truthy
      file = Cosmos.write_exception_file(RuntimeError.new, 'test2_exception', File.dirname(__FILE__))
      File.exist?(file).should be_truthy
      Cosmos.cleanup_exceptions()
    end
  end

  describe "catch_fatal_exception" do
    it "should catch exceptions before the GUI is available" do
      capture_io do |stdout|
        system_exit_count = $system_exit_count
        Cosmos.catch_fatal_exception do
          raise "AHHH!!!"
        end
        $system_exit_count.should eql(system_exit_count + 1)
        stdout.string.should match "Fatal Exception! Exiting..."
      end
      Cosmos.cleanup_exceptions()
    end
  end

  describe "handle_fatal_exception" do
    it "should write to the Logger and exit" do
      capture_io do |stdout|
        system_exit_count = $system_exit_count
        Cosmos.handle_fatal_exception(RuntimeError.new)
        $system_exit_count.should eql(system_exit_count + 1)
        stdout.string.should match "Fatal Exception! Exiting..."
      end
      Cosmos.cleanup_exceptions()
    end
  end

  describe "handle_critical_exception" do
    it "should write to the Logger" do
      capture_io do |stdout|
        system_exit_count = $system_exit_count
        Cosmos.handle_critical_exception(RuntimeError.new)
        $system_exit_count.should eql(system_exit_count)
        stdout.string.should match "Critical Exception!"
      end
      Cosmos.cleanup_exceptions()
    end
  end

  describe "safe_thread" do
    it "should handle exceptions" do
      capture_io do |stdout|
        thread = Cosmos.safe_thread("Test", 1) do
          raise "TestError"
        end
        sleep 1
        stdout.string.should match "Test thread unexpectedly died."
        thread.kill
        sleep(0.2)
      end
      Cosmos.cleanup_exceptions()
    end
  end

  describe "require_class" do
    it "should require the class represented by the filename" do
      # Explicitly load cosmos.rb to ensure the Cosmos::USERPATH/lib
      # directory is in the path
      load 'cosmos.rb'

      expect { Cosmos.require_class("my_test_class.rb") }.to raise_error(/Unable to require my_test_class.rb/)
      filename = File.join(Cosmos::USERPATH,"lib","my_test_class.rb")
      File.open(filename,'w') do |file|
        file.puts "class MyTestClass"
        file.puts "end"
      end

      Cosmos.require_class("my_test_class.rb")
      File.delete(filename)
    end
  end

  describe "open_in_text_editor" do
    it "should open the file in a text editor" do
      expect(Cosmos).to receive(:system).with(/#{File.basename(__FILE__)}/)
      Cosmos.open_in_text_editor(__FILE__)
    end
  end

  describe "open_in_web_browser" do
    it "should open the file in a web browser" do
      expect(Cosmos).to receive(:system).with(/#{File.basename(__FILE__)}/)
      Cosmos.open_in_web_browser(__FILE__)
    end
  end
end

