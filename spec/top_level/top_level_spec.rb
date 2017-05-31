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
  it "has accessors" do
    error = HazardousError.new
    error.target_name = "TGT"
    expect(error.target_name).to eql "TGT"
    error.cmd_name = "CMD"
    expect(error.cmd_name).to eql "CMD"
    error.cmd_params = ["ID","BLAH"]
    expect(error.cmd_params).to eql ["ID","BLAH"]
    error.hazardous_description = "Description"
    expect(error.hazardous_description).to eql "Description"
  end
end

module Cosmos
  def self.cleanup_exceptions
    # Delete the 'exception' files
    Dir[File.join(System.paths['LOGS'], '*')].each {|file| FileUtils.rm_f file }
    Dir[File.join(File.dirname(__FILE__),"*exception.txt")].each {|file| FileUtils.rm_f file }
  end

  describe "FatalError" do
    it "is a StandardError" do
      expect(FatalError.new).to be_a StandardError
    end
  end

  describe "self.disable_warnings" do
    it "disables Ruby warnings" do
      stderr = StringIO.new('', 'r+')
      $stderr = stderr
      save = Cosmos::PATH
      Cosmos::PATH = "HI"
      expect(stderr.string).to match /warning\: already initialized constant/
      Cosmos::PATH = save

      save_mutex = Cosmos::COSMOS_MUTEX
      Cosmos.disable_warnings do
        Cosmos::COSMOS_MUTEX = "HI"
        Cosmos::COSMOS_MUTEX = save_mutex
      end
      expect(stderr.string).not_to match "warning: already initialized constant COSMOS_MUTEX"
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

    it "is initially set" do
      expect(Cosmos::USERPATH).not_to be_nil
    end

    context "when searching for userpath.txt" do
      it "giveups if it can't be found" do
        old = Cosmos::USERPATH
        Cosmos.define_user_path(Dir.home)
        expect(Cosmos::USERPATH).to eql old
      end

      it "sets the path to where userpath.txt is found" do
        ENV.delete('COSMOS_USERPATH')
        old = Cosmos::USERPATH
        expect(old).not_to eql File.dirname(__FILE__)
        File.open(File.join(File.dirname(__FILE__), 'userpath.txt'),'w') {|f| f.puts '' }
        Cosmos.define_user_path(File.dirname(__FILE__))
        expect(Cosmos::USERPATH).to eql File.dirname(__FILE__)
        File.delete(File.join(File.dirname(__FILE__), 'userpath.txt'))
      end
    end
  end

  describe "self.add_to_search_path" do
    it "adds a directory to the Ruby search path" do
      if Kernel.is_windows?
        expect($:).not_to include("C:/test/path")
        Cosmos.add_to_search_path("C:/test/path")
        expect($:).to include("C:/test/path")
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

    it "dumps and load a Ruby object" do
      capture_io do |stdout|
        # Configure the user path to be local
        ENV['COSMOS_USERPATH'] = File.dirname(__FILE__)
        Cosmos.define_user_path

        array = [1,2,3,4]
        Cosmos.marshal_dump('marshal_test', array)
        array_load = Cosmos.marshal_load('marshal_test')
        expect(File.exist?(File.join(Cosmos::USERPATH,'marshal_test'))).to be true
        expect(array).to eql array_load
        File.delete(File.join(Cosmos::USERPATH,'marshal_test'))
      end
    end

    it "rescues marshal dump errors" do
      capture_io do |stdout|
        system_exit_count = $system_exit_count
        Cosmos.marshal_dump('marshal_test', Proc.new { '' })
        expect($system_exit_count).to be > system_exit_count
        expect(stdout.string).to match "no _dump_data is defined for class Proc"
      end
      Cosmos.cleanup_exceptions()
    end

    it "rescues marshal load errors" do
      # Attempt to load something that doesn't exist
      expect(Cosmos.marshal_load('blah')).to be_nil

      # Attempt to load something that doesn't have the marshal header
      File.open(File.join(Cosmos::USERPATH,'marshal_test'),'wb') {|f| f.puts "marshal!" }
      expect(Cosmos.marshal_load('marshal_test')).to be_nil

      # Attempt to load something that has a bad marshal
      File.open(File.join(Cosmos::USERPATH,'marshal_test'),'wb') do |file|
        file.write(Cosmos::COSMOS_MARSHAL_HEADER)
        file.write("\x00\x01")
      end

      capture_io do |stdout|
        Cosmos.marshal_load('marshal_test')
        expect(stdout.string).to match "Marshal load failed with exception"
      end
      Cosmos.cleanup_exceptions()
    end
  end

  describe "run_process" do
    it "returns a Thread" do
      if Kernel.is_windows?
        capture_io do |stdout|
          thread = Cosmos.run_process("ping google.com -n 2 -w 1000 > nul")
          sleep 0.1
          expect(thread).to be_a Thread
          expect(thread.alive?).to be true
          sleep 2
          expect(thread.alive?).to be false
        end
      end
    end
  end

  describe "run_process_check_output" do
    it "executes a command while capturing output" do
      if Kernel.is_windows?
        require 'Qt'
        allow(::Qt::Application).to receive(:instance).and_return(nil)
        output = ''
        allow(Logger).to receive(:error) {|str| output = str}
        thread = Cosmos.run_process_check_output("ping 192.0.0.234 -n 1 -w 1000")
        sleep 0.1 while thread.alive?
        expect(output).to match "Pinging 192.0.0.234"
      end
    end
  end

  describe "md5_files" do
    it "calculates a MD5 sum across files" do
      File.open(File.join(Cosmos::USERPATH,'test1.txt'),'w') {|f| f.puts "test1" }
      File.open(File.join(Cosmos::USERPATH,'test2.txt'),'w') {|f| f.puts "test2" }
      digest = Cosmos.md5_files(["test1.txt", "test2.txt"])
      expect(digest.digest.length).to be 16
      expect(digest.hexdigest).to eql 'e51dfbea83de9c7e6b49560089d8a170'
      File.delete(File.join(Cosmos::USERPATH, 'test1.txt'))
      File.delete(File.join(Cosmos::USERPATH, 'test2.txt'))
    end
  end

  describe "create_log_file" do
    it "creates a log file even if System LOGS doesn't exist" do
      filename = Cosmos.create_log_file('test', 'X:/directory/which/does/not/exit')
      expect(File.exist?(filename)).to be true
      File.delete(filename)

      Cosmos.set_working_dir do
        # Move the defaults output dir out of the way for this test
        begin
          FileUtils.mv('outputs', 'outputs_bak')
        rescue => err
          Dir.entries('outputs/logs').each do |entry|
            next if entry[0] == '.'
            begin
              FileUtils.rm(File.join('outputs', 'logs', entry))
            rescue
              STDOUT.puts entry
            end
          end
          raise err
        end

        # Create a logs directory as the first order backup
        FileUtils.mkdir('logs')
        filename = Cosmos.create_log_file('test', 'X:/directory/which/does/not/exit')
        expect(File.exist?(filename)).to be true
        File.delete(filename)

        # Delete logs and see if we still get a log file
        FileUtils.rm_rf('logs')
        filename = Cosmos.create_log_file('test', 'X:/directory/which/does/not/exit')
        expect(File.exist?(filename)).to be true
        File.delete(filename)

        # Restore outputs
        FileUtils.mv('outputs_bak', 'outputs')
      end
    end
  end

  describe "write_exception_file" do
    it "writes an exception file" do
      file = Cosmos.write_exception_file(nil, 'test1_exception', File.dirname(__FILE__))
      expect(File.exist?(file)).to be true
      file = Cosmos.write_exception_file(RuntimeError.new, 'test2_exception', File.dirname(__FILE__))
      expect(File.exist?(file)).to be true
      Cosmos.cleanup_exceptions()
    end
  end

  describe "catch_fatal_exception" do
    it "catches exceptions before the GUI is available" do
      capture_io do |stdout|
        system_exit_count = $system_exit_count
        Cosmos.catch_fatal_exception do
          raise "AHHH!!!"
        end
        expect($system_exit_count).to eql(system_exit_count + 1)
        expect(stdout.string).to match "Fatal Exception! Exiting..."
      end
      Cosmos.cleanup_exceptions()
    end
  end

  describe "handle_fatal_exception" do
    it "writes to the Logger and exit" do
      capture_io do |stdout|
        system_exit_count = $system_exit_count
        Cosmos.handle_fatal_exception(RuntimeError.new)
        expect($system_exit_count).to eql(system_exit_count + 1)
        expect(stdout.string).to match "Fatal Exception! Exiting..."
      end
      Cosmos.cleanup_exceptions()
    end
  end

  describe "handle_critical_exception" do
    it "writes to the Logger" do
      capture_io do |stdout|
        system_exit_count = $system_exit_count
        Cosmos.handle_critical_exception(RuntimeError.new)
        expect($system_exit_count).to eql(system_exit_count)
        expect(stdout.string).to match "Critical Exception!"
      end
      Cosmos.cleanup_exceptions()
    end
  end

  describe "safe_thread" do
    it "handles exceptions" do
      capture_io do |stdout|
        thread = Cosmos.safe_thread("Test", 1) do
          raise "TestError"
        end
        def thread.graceful_kill
        end
        sleep 1
        expect(stdout.string).to match "Test thread unexpectedly died."
        Cosmos.kill_thread(thread, thread)
      end
      Cosmos.cleanup_exceptions()
    end
  end

  describe "require_class" do
    it "requires the class represented by the filename" do
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

  describe "open_file_browser" do
    it "opens a file browser" do
      unless ENV['TRAVIS']
        expect(Cosmos).to receive(:system).with(/#{Dir.pwd}/)
        Cosmos.open_file_browser(Dir.pwd)
      end
    end
  end

  describe "open_in_text_editor" do
    it "opens the file in a text editor" do
      unless ENV['TRAVIS']
        expect(Cosmos).to receive(:system).with(/#{File.basename(__FILE__)}/)
        Cosmos.open_in_text_editor(__FILE__)
      end
    end
  end

  describe "open_in_web_browser" do
    it "opens the file in a web browser" do
      expect(Cosmos).to receive(:system).with(/#{File.basename(__FILE__)}/)
      Cosmos.open_in_web_browser(__FILE__)
    end
  end
end

