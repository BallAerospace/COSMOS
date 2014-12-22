# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
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
    after(:all) do
      clean_config()
    end

    describe "start, stop" do
      it "should call start on each task" do
        File.open(File.join(Cosmos::USERPATH,'lib','my_bg_task1.rb'),'w') do |file|
          file.puts "require 'cosmos/tools/cmd_tlm_server/background_task'"
          file.puts "class MyBgTask1 < Cosmos::BackgroundTask"
          file.puts "  def call; sleep 1 while true; end"
          file.puts "  def stop; raise 'Error'; end"
          file.puts "end"
        end
        tf = Tempfile.new('unittest')
        tf.puts 'BACKGROUND_TASK my_bg_task1.rb'
        tf.close
        config = CmdTlmServerConfig.new(tf.path)
        bt = BackgroundTasks.new(config)
        num_threads = Thread.list.length
        bt.start
        sleep 0.1
        Thread.list.length.should eql (num_threads + 1)
        bt.stop
        sleep 0.1
        Thread.list.length.should eql num_threads

        tf.unlink
        File.delete(File.join(Cosmos::USERPATH,'lib','my_bg_task1.rb'))
      end

      it "should handle exceptions" do
        tf = Tempfile.new('unittest')
        tf.puts 'BACKGROUND_TASK my_bg_task2.rb'
        tf.close
        capture_io do |stdout|
          File.open(File.join(Cosmos::USERPATH,'lib','my_bg_task2.rb'),'w') do |file|
            file.puts "require 'cosmos/tools/cmd_tlm_server/background_task'"
            file.puts "class MyBgTask2 < Cosmos::BackgroundTask"
            file.puts "  def call; raise 'Error'; end"
            file.puts "  def stop; raise 'Error'; end"
            file.puts "end"
          end
          config = CmdTlmServerConfig.new(tf.path)
          bt = BackgroundTasks.new(config)
          num_threads = Thread.list.length
          bt.start
          Thread.list.length.should eql (num_threads + 1)
          sleep 1.1 # Allow the thread to crash
          Thread.list.length.should eql num_threads
          bt.stop
          sleep 0.1
          Thread.list.length.should eql num_threads

          stdout.string.should match "Background Task thread unexpectedly died"
        end
        tf.unlink
        File.delete(File.join(Cosmos::USERPATH,'lib','my_bg_task2.rb'))
      end
    end

  end
end

