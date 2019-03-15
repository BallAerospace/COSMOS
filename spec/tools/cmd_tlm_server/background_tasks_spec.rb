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
require 'cosmos/tools/cmd_tlm_server/background_tasks'
require 'tempfile'
load 'cosmos.rb' # Ensure COSMOS::USERPATH/lib is set

module Cosmos

  describe BackgroundTasks do
    before(:all) do
      4.times.each do |i|
        File.open(File.join(Cosmos::USERPATH,'lib',"my_bg_task#{i}.rb"),'w') do |file|
          file.puts "require 'cosmos/tools/cmd_tlm_server/background_task'"
          file.puts "class MyBgTask#{i} < Cosmos::BackgroundTask"
          if i == 3
            file.puts "  def call; puts 'BG#{i} START'; raise 'Error'; end"
          else
            file.puts "  def call; puts 'BG#{i} START'; @go = true; sleep 1 while @go; end"
          end
          file.puts "  def stop; puts 'BG#{i} STOP'; @go = false; end"
          file.puts "end"
        end
      end
    end

    after(:all) do
      4.times.each { |i| File.delete(File.join(Cosmos::USERPATH,'lib',"my_bg_task#{i}.rb")) }
    end

    describe "start_all, stop_all" do
      it "starts and stops all background tasks" do
        tf = Tempfile.new('unittest')
        tf.puts 'BACKGROUND_TASK my_bg_task0.rb'
        tf.puts 'BACKGROUND_TASK my_bg_task1.rb'
        tf.puts '  STOPPED'
        tf.puts 'BACKGROUND_TASK my_bg_task2.rb'
        tf.close
        config = CmdTlmServerConfig.new(tf.path)
        bt = BackgroundTasks.new(config)
        expect(running_threads.length).to eql(1) # RSpec main thread
        expect(bt.instance_variable_get("@threads").length).to eq 0

        capture_io do |stdout|
          bt.start_all
          sleep 0.2
          expect(running_threads.length).to eql(3)
          expect(bt.instance_variable_get("@threads").compact.length).to eq 2
          expect(stdout.string).to match("BG0 START")
          expect(stdout.string).to match("BG2 START")

          bt.start(1)
          sleep 0.1
          expect(running_threads.length).to eql(4)
          expect(bt.instance_variable_get("@threads").compact.length).to eq 3
          expect(stdout.string).to match("BG1 START")

          bt.stop_all
          sleep 0.2
          expect(running_threads.length).to eql(1)
          expect(bt.instance_variable_get("@threads").compact.length).to eq 0
          expect(stdout.string).to match("BG0 STOP")
          expect(stdout.string).to match("BG1 STOP")
          expect(stdout.string).to match("BG2 STOP")
        end
        tf.unlink
      end
    end

    describe "start, stop" do
      it "starts and stops individual background tasks" do
        tf = Tempfile.new('unittest')
        tf.puts 'BACKGROUND_TASK my_bg_task0.rb'
        tf.puts 'BACKGROUND_TASK my_bg_task1.rb'
        tf.puts 'BACKGROUND_TASK my_bg_task2.rb'
        tf.close
        config = CmdTlmServerConfig.new(tf.path)
        bt = BackgroundTasks.new(config)
        expect(running_threads.length).to eql(1) # RSpec main thread
        expect(bt.instance_variable_get("@threads").length).to eq 0

        capture_io do |stdout|
          expect { bt.start(3) }.to raise_error(/No task at index 3/)

          bt.start(2)
          sleep 0.1
          expect(running_threads.length).to eql(2)
          expect(bt.instance_variable_get("@threads")[2].alive?).to eq true
          expect(bt.instance_variable_get("@threads").compact.length).to eq 1
          expect(stdout.string).to match("BG2 START")

          bt.start(1)
          sleep 0.1
          expect(running_threads.length).to eql(3)
          expect(bt.instance_variable_get("@threads")[1].alive?).to eq true
          expect(bt.instance_variable_get("@threads").compact.length).to eq 2
          expect(stdout.string).to match("BG1 START")

          bt.start(0)
          sleep 0.1
          expect(running_threads.length).to eql(4)
          expect(bt.instance_variable_get("@threads")[0].alive?).to eq true
          expect(bt.instance_variable_get("@threads").compact.length).to eq 3
          expect(stdout.string).to match("BG0 START")

          bt.start(2) # Should do nothing since the task is already started
          sleep 0.1
          expect(running_threads.length).to eql(4)
          expect(bt.instance_variable_get("@threads").compact.length).to eq 3
          expect(stdout.string).to match("BG0 START") # No change

          bt.stop(1)
          sleep 0.2
          expect(running_threads.length).to eql(3)
          expect(bt.instance_variable_get("@threads")[1]).to be_nil
          expect(bt.instance_variable_get("@threads").compact.length).to eq 2
          expect(stdout.string).to match("BG1 STOP")

          bt.stop(0)
          sleep 0.2
          expect(running_threads.length).to eql(2)
          expect(bt.instance_variable_get("@threads")[0]).to be_nil
          expect(bt.instance_variable_get("@threads").compact.length).to eq 1
          expect(stdout.string).to match("BG0 STOP")

          bt.stop(2)
          sleep 0.2
          expect(running_threads.length).to eql(1)
          expect(bt.instance_variable_get("@threads")[2]).to be_nil
          expect(bt.instance_variable_get("@threads").compact.length).to eq 0
          expect(stdout.string).to match("BG2 STOP")

          bt.stop(0) # Should be safe to stop something already stopped
          sleep 0.2
          expect(running_threads.length).to eql(1)
          expect(bt.instance_variable_get("@threads").compact.length).to eq 0
          expect(stdout.string).to match("BG2 STOP") # No change

          expect { bt.stop(3) }.to raise_error(/No task at index 3/)
        end
        tf.unlink
      end

      it "handles exceptions" do
        tf = Tempfile.new('unittest')
        tf.puts 'BACKGROUND_TASK my_bg_task3.rb'
        tf.close
        config = CmdTlmServerConfig.new(tf.path)
        bt = BackgroundTasks.new(config)
        expect(running_threads.length).to eql(1) # RSpec main thread
        expect(bt.instance_variable_get("@threads").length).to eq 0

        capture_io do |stdout|
          bt.start_all
          # 2 because the RSpec main thread plus the background task
          expect(running_threads.length).to eql(2)
          expect(bt.instance_variable_get("@threads").length).to eq 1
          expect(bt.instance_variable_get("@threads")[0].alive?).to eq true
          sleep 1.1 # Allow the thread to crash
          expect(running_threads.length).to eql(1)
          expect(bt.instance_variable_get("@threads")[0]).to be_nil
          expect(stdout.string).to match("unexpectedly died")
        end

        # Try to restart the task
        capture_io do |stdout|
          bt.start_all
          # 2 because the RSpec main thread plus the background task
          expect(running_threads.length).to eql(2)
          expect(bt.instance_variable_get("@threads").length).to eq 1
          expect(bt.instance_variable_get("@threads")[0].alive?).to eq true
          sleep 1.1 # Allow the thread to crash
          expect(running_threads.length).to eql(1)
          expect(bt.instance_variable_get("@threads")[0]).to be_nil
          expect(stdout.string).to match("unexpectedly died")
        end
        tf.unlink
      end
    end
  end
end
