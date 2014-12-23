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
require 'cosmos/system/target'
require 'tempfile'

module Cosmos

  describe Target do
    after(:all) do
      FileUtils.rm_rf File.join(Cosmos::USERPATH,'target_spec_temp')
    end

    describe "initialize" do
      it "should create a target with the given name" do
        Target.new("TGT").name.should eql "TGT"
      end

      it "should create a target with the given substitute name" do
        tgt = Target.new("TGT","TGT2")
        tgt.name.should eql "TGT2"
        tgt.original_name.should eql "TGT"
      end

      it "should create a target with the default dir" do
        Target.new("TGT").dir.should eql File.join(USERPATH,'config','targets','TGT')
      end

      it "should create a target with an override path" do
        saved = File.join(USERPATH,'saved')
        Target.new("TGT",nil,saved).dir.should eql File.join(saved,'TGT')
      end

      it "should record all the command and telemetry files in the target directory" do
        tgt_path = File.join(Cosmos::USERPATH,'target_spec_temp')
        tgt_name = "TEST"
        cmd_tlm = File.join(tgt_path,tgt_name,'cmd_tlm')
        FileUtils.mkdir_p(cmd_tlm)
        File.open(File.join(cmd_tlm,'cmd1.txt'),'w') {}
        File.open(File.join(cmd_tlm,'cmd2.txt'),'w') {}
        File.open(File.join(cmd_tlm,'tlm1.txt'),'w') {}
        File.open(File.join(cmd_tlm,'tlm2.txt'),'w') {}

        tgt = Target.new(tgt_name,nil,tgt_path)
        tgt.dir.should eql File.join(tgt_path,tgt_name)
        files = Dir[File.join(cmd_tlm,'*.txt')]
        files.should_not be_empty
        tgt.cmd_tlm_files.length.should eql 4
        tgt.cmd_tlm_files.sort.should eql files.sort

        FileUtils.rm_r(tgt_path)
      end

      it "should process a target.txt in the target directory" do
        tgt_path = File.join(Cosmos::USERPATH,'target_spec_temp')
        tgt_name = "TEST"
        tgt_dir = File.join(tgt_path,tgt_name)
        FileUtils.mkdir_p(tgt_dir)
        File.open(File.join(tgt_dir,'target.txt'),'w') do |file|
          file.puts("IGNORE_PARAMETER TEST")
        end

        tgt = Target.new(tgt_name,nil,tgt_path)
        tgt.dir.should eql tgt_dir
        tgt.ignored_parameters.should eql ["TEST"]

        FileUtils.rm_r(tgt_path)
      end

      it "should process an alternative target.txt in the target directory" do
        tgt_path = File.join(Cosmos::USERPATH,'target_spec_temp')
        tgt_name = "TEST"
        tgt_dir = File.join(tgt_path,tgt_name)
        FileUtils.mkdir_p(tgt_dir)
        File.open(File.join(tgt_dir,'target_other.txt'),'w') do |file|
          file.puts("IGNORE_PARAMETER BOB")
        end

        tgt = Target.new(tgt_name,nil,tgt_path, 'target_other.txt')
        tgt.dir.should eql tgt_dir
        tgt.ignored_parameters.should eql ["BOB"]

        FileUtils.rm_r(tgt_path)
      end
    end

    describe "process_file" do
      it "should complain about unknown keywords" do
        tf = Tempfile.new('unittest')
        tf.puts("BLAH")
        tf.close
        expect { Target.new("TGT").process_file(tf.path) }.to raise_error(ConfigParser::Error, "Unknown keyword 'BLAH'")
        tf.unlink
      end

      context "with REQUIRE" do
        it "should take 1 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("REQUIRE")
          tf.close
          expect { Target.new("TGT").process_file(tf.path) }.to raise_error(ConfigParser::Error, "Not enough parameters for REQUIRE.")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("REQUIRE my_file.rb TRUE")
          tf.close
          expect { Target.new("TGT").process_file(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for REQUIRE.")
          tf.unlink
        end

        it "should complain if the file doesn't exist" do
          tf = Tempfile.new('unittest')
          tf.puts("REQUIRE my_file.rb")
          tf.close
          expect { Target.new("TGT").process_file(tf.path) }.to raise_error(ConfigParser::Error, /Unable to require my_file.rb/)
          tf.unlink
        end

        it "should require the file" do
          filename = File.join(File.dirname(__FILE__),'..','..','lib','my_file.rb')
          File.open(filename, 'w') do |file|
            file.puts "class MyFile"
            file.puts "end"
          end
          tf = Tempfile.new('unittest')
          tf.puts("REQUIRE my_file.rb")
          tf.close
          Target.new("TGT").process_file(tf.path)
          expect { MyFile.new }.to_not raise_error
          File.delete filename
          tf.unlink
        end
      end

      context "with IGNORE_PARAMETER" do
        it "should take 1 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("IGNORE_PARAMETER")
          tf.close
          expect { Target.new("TGT").process_file(tf.path) }.to raise_error(ConfigParser::Error, "Not enough parameters for IGNORE_PARAMETER.")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("IGNORE_PARAMETER my_file.rb TRUE")
          tf.close
          expect { Target.new("TGT").process_file(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for IGNORE_PARAMETER.")
          tf.unlink
        end

        it "should store the parameter" do
          tf = Tempfile.new('unittest')
          tf.puts("IGNORE_PARAMETER TEST")
          tf.close
          tgt = Target.new("TGT")
          tgt.process_file(tf.path)
          tgt.ignored_parameters.should eql ["TEST"]
          tf.unlink
        end
      end

      context "with COMMANDS and TELEMETRY" do
        it "should take 1 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("COMMANDS")
          tf.close
          expect { Target.new("TGT").process_file(tf.path) }.to raise_error(ConfigParser::Error, "Not enough parameters for COMMANDS.")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("COMMANDS tgt_cmds.txt TRUE")
          tf.close
          expect { Target.new("TGT").process_file(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for COMMANDS.")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("TELEMETRY")
          tf.close
          expect { Target.new("TGT").process_file(tf.path) }.to raise_error(ConfigParser::Error, "Not enough parameters for TELEMETRY.")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("TELEMETRY tgt_tlm.txt TRUE")
          tf.close
          expect { Target.new("TGT").process_file(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for TELEMETRY.")
          tf.unlink
        end

        it "should store the filename" do
          tgt_path = File.join(Cosmos::USERPATH,'target_spec_temp')
          tgt_name = "TEST"
          tgt_dir = File.join(tgt_path,tgt_name)
          FileUtils.mkdir_p(tgt_dir)
          FileUtils.mkdir_p(tgt_dir + '/cmd_tlm')
          File.open(tgt_dir + '/cmd_tlm/tgt_cmds.txt', 'w') {|file| file.puts "# comment"}
          File.open(tgt_dir + '/cmd_tlm/tgt_cmds2.txt', 'w') {|file| file.puts "# comment"}
          File.open(tgt_dir + '/cmd_tlm/tgt_cmds3.txt', 'w') {|file| file.puts "# comment"}
          File.open(tgt_dir + '/cmd_tlm/tgt_tlm.txt', 'w') {|file| file.puts "# comment"}
          File.open(tgt_dir + '/cmd_tlm/tgt_tlm2.txt', 'w') {|file| file.puts "# comment"}
          File.open(tgt_dir + '/cmd_tlm/tgt_tlm3.txt', 'w') {|file| file.puts "# comment"}
          File.open(File.join(tgt_dir,'target.txt'),'w') do |file|
            file.puts("COMMANDS tgt_cmds2.txt")
            file.puts("TELEMETRY tgt_tlm3.txt")
          end

          tgt = Target.new(tgt_name,nil,tgt_path)
          tgt.dir.should eql tgt_dir
          tgt.cmd_tlm_files.length.should eql 2
          tgt.cmd_tlm_files.should eql [tgt_dir + '/cmd_tlm/tgt_cmds2.txt', tgt_dir + '/cmd_tlm/tgt_tlm3.txt']

          FileUtils.rm_r(tgt_dir)
        end

        it "filenames must exist" do
          tgt_path = File.join(Cosmos::USERPATH,'target_spec_temp')
          tgt_name = "TEST"
          tgt_dir = File.join(tgt_path,tgt_name)
          FileUtils.mkdir_p(tgt_dir)
          FileUtils.mkdir_p(tgt_dir + '/cmd_tlm')
          File.open(tgt_dir + '/cmd_tlm/tgt_cmds.txt', 'w') {|file| file.puts "# comment"}
          File.open(tgt_dir + '/cmd_tlm/tgt_cmds2.txt', 'w') {|file| file.puts "# comment"}
          File.open(tgt_dir + '/cmd_tlm/tgt_cmds3.txt', 'w') {|file| file.puts "# comment"}
          File.open(tgt_dir + '/cmd_tlm/tgt_tlm.txt', 'w') {|file| file.puts "# comment"}
          File.open(tgt_dir + '/cmd_tlm/tgt_tlm2.txt', 'w') {|file| file.puts "# comment"}
          File.open(tgt_dir + '/cmd_tlm/tgt_tlm3.txt', 'w') {|file| file.puts "# comment"}
          File.open(File.join(tgt_dir,'target.txt'),'w') do |file|
            file.puts("COMMANDS tgt_cmds4.txt")
            file.puts("TELEMETRY tgt_tlm4.txt")
          end

          expect { Target.new(tgt_name,nil,tgt_path) }.to raise_error(ConfigParser::Error, "#{tgt_dir + '/cmd_tlm/tgt_cmds4.txt'} not found")

          FileUtils.rm_r(tgt_dir)
        end
      end
    end

  end
end

