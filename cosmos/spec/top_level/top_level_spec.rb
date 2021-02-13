# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

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
      expect(stderr.string).to match(/warning: already initialized constant/)
      Cosmos::PATH = save

      save_mutex = Cosmos::COSMOS_MUTEX
      Cosmos.disable_warnings do
        Cosmos::COSMOS_MUTEX = "HI"
        Cosmos::COSMOS_MUTEX = save_mutex
      end
      expect(stderr.string).not_to match("warning: already initialized constant COSMOS_MUTEX")
      $stderr = STDERR
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
    it "dumps and load a Ruby object" do
      capture_io do |stdout|
        # Configure the user path to be local
        # ENV['COSMOS_USERPATH'] = File.dirname(__FILE__)

        array = [1,2,3,4]
        Cosmos.marshal_dump('marshal_test', array)
        array_load = Cosmos.marshal_load('marshal_test')
        expect(File.exist?(File.join(Cosmos::PATH,'marshal_test'))).to be true
        expect(array).to eql array_load
        File.delete(File.join(Cosmos::PATH,'marshal_test'))
      end
    end

    it "rescues marshal dump errors" do
      capture_io do |stdout|
        system_exit_count = $system_exit_count
        Cosmos.marshal_dump('marshal_test', Proc.new { '' })
        expect($system_exit_count).to be > system_exit_count
        expect(stdout.string).to match("is defined for class Proc")
      end
      Cosmos.cleanup_exceptions()
    end

    it "rescues marshal dump errors in a Packet with a Mutex" do
      capture_io do |stdout|
        system_exit_count = $system_exit_count
        pkt = Packet.new("TGT","PKT")
        pkt.append_item("ITEM", 16, :UINT)
        pkt.read_all
        Cosmos.marshal_dump('marshal_test', pkt)
        expect($system_exit_count).to be > system_exit_count
        expect(stdout.string).to match("Mutex exists in a packet")
      end
      Cosmos.cleanup_exceptions()
    end

    it "rescues marshal load errors" do
      # Attempt to load something that doesn't exist
      expect(Cosmos.marshal_load('blah')).to be_nil

      # Attempt to load something that doesn't have the marshal header
      File.open(File.join(Cosmos::PATH,'marshal_test'),'wb') {|f| f.puts "marshal!" }
      expect(Cosmos.marshal_load('marshal_test')).to be_nil

      # Attempt to load something that has a bad marshal
      File.open(File.join(Cosmos::PATH,'marshal_test'),'wb') do |file|
        file.write(Cosmos::COSMOS_MARSHAL_HEADER)
        file.write("\x00\x01")
      end

      capture_io do |stdout|
        Cosmos.marshal_load('marshal_test')
        expect(stdout.string).to match("Marshal load failed with exception")
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
      if RUBY_ENGINE == 'ruby' and Kernel.is_windows?
        output = ''
        allow(Logger).to receive(:error) {|str| output = str}
        thread = Cosmos.run_process_check_output("ping 192.0.0.234 -n 1 -w 1000")
        sleep 0.1 while thread.alive?
        expect(output).to match("Pinging 192.0.0.234")
      end
    end
  end

  describe "hash_files" do
    xit "calculates a hashing sum across files in md5 mode" do
      File.open(File.join(Cosmos::PATH,'test1.txt'),'w') {|f| f.puts "test1" }
      File.open(File.join(Cosmos::PATH,'test2.txt'),'w') {|f| f.puts "test2" }
      digest = Cosmos.hash_files(["test1.txt", "test2.txt"])
      expect(digest.digest.length).to be 16
      expect(digest.hexdigest).to eql 'e51dfbea83de9c7e6b49560089d8a170'
      File.delete(File.join(Cosmos::PATH, 'test1.txt'))
      File.delete(File.join(Cosmos::PATH, 'test2.txt'))
    end

    it "calculates a hashing sum across files in sha256 mode" do
      File.open(File.join(Cosmos::PATH,'test1.txt'),'w') {|f| f.puts "test1" }
      File.open(File.join(Cosmos::PATH,'test2.txt'),'w') {|f| f.puts "test2" }
      digest = Cosmos.hash_files(["test1.txt", "test2.txt"], nil, 'SHA256')
      expect(digest.digest.length).to be 32
      expect(digest.hexdigest).to eql '49789e7c809eb38ea34864b00e2cfd68825e0c07cd7b7d0c6fe2642ac87a919c'
      File.delete(File.join(Cosmos::PATH, 'test1.txt'))
      File.delete(File.join(Cosmos::PATH, 'test2.txt'))
    end
  end


  describe "create_log_file" do
    it "creates a log file in System LOGS" do
      filename1 = Cosmos.create_log_file('test')
      expect(File.exist?(filename1)).to be true
      File.delete(filename1)
    end

    it "creates a log file even if System LOGS doesn't exist" do
      filename1 = Cosmos.create_log_file('test', 'X:/directory/which/does/not/exit')
      expect(File.exist?(filename1)).to be true
      # Immediately create another log file to ensure we get unique names
      filename2 = Cosmos.create_log_file('test', 'X:/directory/which/does/not/exit')
      expect(File.exist?(filename2)).to be true
      # Ensure the filenames are unique
      expect(filename1).to_not eql filename2
      File.delete(filename1)
      File.delete(filename2)

      Cosmos.set_working_dir(Cosmos::USERPATH) do
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
        expect(stdout.string).to match("Fatal Exception! Exiting...")
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
        expect(stdout.string).to match("Fatal Exception! Exiting...")
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
        expect(stdout.string).to match("Critical Exception!")
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
        expect(stdout.string).to match("Test thread unexpectedly died.")
        Cosmos.kill_thread(thread, thread)
      end
      Cosmos.cleanup_exceptions()
    end
  end

  describe "require_class" do
    it "requires the class represented by the filename" do
      filename = File.join(Cosmos::PATH,"lib","my_test_class.rb")
      File.delete(filename) if File.exist? filename

      File.open(filename,'w') do |file|
        file.puts "class MyTestClass"
        file.puts "end"
      end

      klass = Cosmos.require_class("my_test_class.rb")
      expect(klass).to be_a(Class)
      expect(klass).to eq MyTestClass
      File.delete(filename)
    end

    it "requires the class represented by the classname" do
      filename = File.join(Cosmos::PATH,"lib","my_other_test_class.rb")
      File.delete(filename) if File.exist? filename

      File.open(filename,'w') do |file|
        file.puts "class MyOtherTestClass"
        file.puts "end"
      end

      klass = Cosmos.require_class("MyOtherTestClass")
      expect(klass).to be_a(Class)
      expect(klass).to eq MyOtherTestClass
      File.delete(filename)
    end
  end

  describe "require_file" do
    it "requires the file" do
      filename = File.join(Cosmos::PATH,"lib","my_test_file.rb")
      File.delete(filename) if File.exist? filename

      expect { Cosmos.require_file("my_test_file.rb") }.to raise_error(LoadError, /Unable to require my_test_file.rb/)

      File.open(filename,'w') do |file|
        file.puts "class MyTestFile"
        file.puts "  blah" # This will cause an error
        file.puts "end"
      end
      expect { Cosmos.require_file("my_test_file.rb") }.to raise_error(NameError, /Unable to require my_test_file.rb/)

      File.open(filename,'w') do |file|
        file.puts "class MyTestFile"
        file.puts "end"
      end
      Cosmos.require_file("my_test_file.rb")
      File.delete(filename)
    end
  end

  describe "kill_thread" do
    before(:each) do
      @log_info = ''
      @log_warn = ''
      @log_error = ''
      allow(Logger).to receive(:info) {|str| @log_info << str}
      allow(Logger).to receive(:warn) {|str| @log_warn << str}
      allow(Logger).to receive(:error) {|str| @log_error << str}
    end

    it "calls thread.kill if the thread is alive" do
      thread = Thread.new { loop { sleep 1 } }
      Cosmos.kill_thread(nil, thread) # No thread owner
      expect(@log_info).to match("")
      expect(@log_warn).to match("Failed to gracefully kill thread")
      expect(@log_error).to eql("")
      expect(thread.alive?).to be false
    end

    it "warns if the thread owner doesn't support graceful_kill" do
      thread = Thread.new { loop { sleep 1 } }
      Cosmos.kill_thread(thread, thread)
      expect(@log_info).to match("Thread owner Thread does not support graceful_kill")
      expect(@log_warn).to match("Failed to gracefully kill thread")
      expect(@log_error).to eql("")
      expect(thread.alive?).to be false
    end

    it "warns if the thread owner is the current thread" do
      class MyThread < Thread
        def graceful_kill; end
      end
      thread = MyThread.new do
        Cosmos.kill_thread(thread, thread)
      end
      sleep 0.1 while thread.alive?
      expect(@log_info).to match("")
      expect(@log_warn).to match("Threads cannot graceful_kill themselves")
      expect(@log_error).to eql("")
      expect(thread.alive?).to be false
    end

    it "calls graceful_kill on the owner" do
      class ThreadOwner
        attr_accessor :thread
        def initialize
          @thread = Thread.new { loop { sleep 1 } }
        end
        def graceful_kill
          @thread.kill
        end
      end
      owner = ThreadOwner.new
      Cosmos.kill_thread(owner, owner.thread)
      expect(@log_info).to match("")
      expect(@log_warn).to match("")
      expect(@log_error).to match("")
      expect(owner.thread.alive?).to be false
    end

    it "logs an error if the thread doesn't die" do
      class MyAliveThread
        def alive?; true; end
        def kill; end
        def backtrace; []; end
      end
      Cosmos.kill_thread(nil, MyAliveThread.new)
      expect(@log_info).to match("")
      expect(@log_warn).to match("Failed to gracefully kill thread")
      expect(@log_error).to match("Failed to kill thread")
    end
  end
end
