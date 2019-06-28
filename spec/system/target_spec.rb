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
require 'cosmos/system/target'
require 'tempfile'
require 'pathname'

module Cosmos

  describe Target do
    after(:all) do
      FileUtils.rm_rf File.join(Cosmos::USERPATH,'target_spec_temp')
    end

    describe "initialize" do
      it "creates a target with the given name" do
        expect(Target.new("TGT").name).to eql "TGT"
      end

      it "creates a target with the given substitute name" do
        tgt = Target.new("TGT","TGT2")
        expect(tgt.name).to eql "TGT2"
        expect(tgt.original_name).to eql "TGT"
      end

      it "creates a target with the default dir" do
        expect(Target.new("TGT").dir).to eql File.join(USERPATH,'config','targets','TGT')
      end

      it "creates a target with an override path" do
        saved = File.join(USERPATH,'saved')
        expect(Target.new("TGT",nil,saved).dir).to eql File.join(saved,'TGT')
      end

      it "records all the command and telemetry files in the target directory" do
        tgt_path = File.join(Cosmos::USERPATH,'target_spec_temp')
        tgt_name = "TEST"
        cmd_tlm = File.join(tgt_path,tgt_name,'cmd_tlm')
        FileUtils.mkdir_p(cmd_tlm)
        File.open(File.join(cmd_tlm,'cmd1.txt'),'w') {}
        File.open(File.join(cmd_tlm,'cmd2.txt'),'w') {}
        File.open(File.join(cmd_tlm,'tlm1.txt'),'w') {}
        File.open(File.join(cmd_tlm,'tlm2.txt'),'w') {}
        File.open(File.join(cmd_tlm,'tlm2.txt~'),'w') {}
        File.open(File.join(cmd_tlm,'tlm2.txt.mine'),'w') {}
        File.open(File.join(cmd_tlm,'tlm3.xtce'),'w') {}
        File.open(File.join(cmd_tlm,'tlm3.xtce~'),'w') {}
        File.open(File.join(cmd_tlm,'tlm3.xtce.bak'),'w') {}

        tgt = Target.new(tgt_name,nil,tgt_path)
        expect(tgt.dir).to eql File.join(tgt_path,tgt_name)
        files = Dir[File.join(cmd_tlm,'*.txt')]
        files.concat(Dir[File.join(cmd_tlm,'*.xtce')])
        expect(files).not_to be_empty
        expect(tgt.cmd_tlm_files.length).to eql 5
        expect(tgt.cmd_tlm_files.sort).to eql files.sort

        FileUtils.rm_r(tgt_path)
      end

      it "processes a target.txt in the target directory" do
        tgt_path = File.join(Cosmos::USERPATH,'target_spec_temp')
        tgt_name = "TEST"
        tgt_dir = File.join(tgt_path,tgt_name)
        FileUtils.mkdir_p(tgt_dir)
        File.open(File.join(tgt_dir,'target.txt'),'w') do |file|
          file.puts("IGNORE_PARAMETER TEST")
        end

        tgt = Target.new(tgt_name,nil,tgt_path)
        expect(tgt.dir).to eql tgt_dir
        expect(tgt.ignored_parameters).to eql ["TEST"]

        FileUtils.rm_r(tgt_path)
      end

      it "processes an alternative target.txt in the target directory" do
        tgt_path = File.join(Cosmos::USERPATH,'target_spec_temp')
        tgt_name = "TEST"
        tgt_dir = File.join(tgt_path,tgt_name)
        FileUtils.mkdir_p(tgt_dir)
        File.open(File.join(tgt_dir,'target_other.txt'),'w') do |file|
          file.puts("IGNORE_PARAMETER BOB")
        end

        tgt = Target.new(tgt_name,nil,tgt_path, 'target_other.txt')
        expect(tgt.dir).to eql tgt_dir
        expect(tgt.ignored_parameters).to eql ["BOB"]

        FileUtils.rm_r(tgt_path)
      end
    end

    describe "process_file" do
      it "complains about unknown keywords" do
        tf = Tempfile.new('unittest')
        tf.puts("BLAH")
        tf.close
        expect { Target.new("TGT").process_file(tf.path) }.to raise_error(ConfigParser::Error, /Unknown keyword 'BLAH'/)
        tf.unlink
      end

      context "with REQUIRE" do
        it "takes 1 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("REQUIRE")
          tf.close
          expect { Target.new("INST").process_file(tf.path) }.to raise_error(ConfigParser::Error, /Not enough parameters for REQUIRE./)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("REQUIRE my_file.rb TRUE")
          tf.close
          expect { Target.new("INST").process_file(tf.path) }.to raise_error(ConfigParser::Error, /Too many parameters for REQUIRE./)
          tf.unlink
        end

        it "complains if the file doesn't exist" do
          tf = Tempfile.new('unittest')
          tf.puts("REQUIRE my_file.rb")
          tf.close
          expect { Target.new("INST").process_file(tf.path) }.to raise_error(ConfigParser::Error, /Unable to require my_file.rb/)
          tf.unlink
        end

        it "requires the file in the target lib directory over system lib" do
          filename1 = File.join(Cosmos::USERPATH, 'config', 'targets', 'INST', 'lib', 'tgt_file.rb')
          File.open(filename1, 'w') do |file|
            file.puts "class TgtLibFile"
            file.puts "end"
          end
          filename2 = File.join(Cosmos::USERPATH, 'lib', 'tgt_file.rb')
          File.open(filename2, 'w') do |file|
            file.puts "class SystemLibFile"
            file.puts "end"
          end

          tf = Tempfile.new('unittest')
          tf.puts("REQUIRE tgt_file.rb")
          tf.close
          Target.new("INST").process_file(tf.path)
          expect { TgtLibFile.new }.to_not raise_error
          expect(Object.const_defined?('TgtLibFile')).to be true
          expect(Object.const_defined?('SystemLibFile')).to be false
          File.delete filename1
          File.delete filename2
          tf.unlink
        end

        it "requires the file in the system lib directory" do
          filename = File.join(Cosmos::USERPATH, 'lib', 'system_file.rb')
          File.open(filename, 'w') do |file|
            file.puts "class SystemFile"
            file.puts "end"
          end
          tf = Tempfile.new('unittest')
          tf.puts("REQUIRE system_file.rb")
          tf.close

          # Initial require in target lib shouldn't be reported as error
          expect(Logger).to_not receive(:error)
          target = Target.new("INST")
          target.process_file(tf.path)
          expect { SystemFile.new }.to_not raise_error
          expect(Pathname.new(target.requires[0]).absolute?).to be true
          File.delete filename
          tf.unlink
        end

        it "requires a file with absolute path" do
          filename = File.join(Cosmos::USERPATH, 'abs_path.rb')
          File.open(filename, 'w') do |file|
            file.puts "class AbsPath"
            file.puts "end"
          end
          tf = Tempfile.new('unittest')
          tf.puts("REQUIRE #{File.expand_path(filename)}")
          tf.close

          # Initial require in target lib shouldn't be reported as error
          expect(Logger).to_not receive(:error)
          Target.new("INST").process_file(tf.path)
          expect { AbsPath.new }.to_not raise_error
          File.delete filename
          tf.unlink
        end
      end

      context "with IGNORE_PARAMETER" do
        it "takes 1 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("IGNORE_PARAMETER")
          tf.close
          expect { Target.new("TGT").process_file(tf.path) }.to raise_error(ConfigParser::Error, /Not enough parameters for IGNORE_PARAMETER./)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("IGNORE_PARAMETER my_file.rb TRUE")
          tf.close
          expect { Target.new("TGT").process_file(tf.path) }.to raise_error(ConfigParser::Error, /Too many parameters for IGNORE_PARAMETER./)
          tf.unlink
        end

        it "stores the parameter" do
          tf = Tempfile.new('unittest')
          tf.puts("IGNORE_PARAMETER TEST")
          tf.close
          tgt = Target.new("TGT")
          tgt.process_file(tf.path)
          expect(tgt.ignored_parameters).to eql ["TEST"]
          tf.unlink
        end
      end

      context "with TLM_UNIQUE_ID_MODE" do
        it "takes no parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("")
          tf.close
          tgt = Target.new("TGT")
          tgt.process_file(tf.path)
          expect(tgt.tlm_unique_id_mode).to eql false
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("TLM_UNIQUE_ID_MODE")
          tf.close
          tgt = Target.new("TGT")
          tgt.process_file(tf.path)
          expect(tgt.tlm_unique_id_mode).to eql true
          tf.unlink
        end
      end

      context "with CMD_UNIQUE_ID_MODE" do
        it "takes no parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("")
          tf.close
          tgt = Target.new("TGT")
          tgt.process_file(tf.path)
          expect(tgt.cmd_unique_id_mode).to eql false
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("CMD_UNIQUE_ID_MODE")
          tf.close
          tgt = Target.new("TGT")
          tgt.process_file(tf.path)
          expect(tgt.cmd_unique_id_mode).to eql true
          tf.unlink
        end
      end

      context "with COMMANDS and TELEMETRY" do
        it "takes 1 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("COMMANDS")
          tf.close
          expect { Target.new("TGT").process_file(tf.path) }.to raise_error(ConfigParser::Error, /Not enough parameters for COMMANDS./)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("COMMANDS tgt_cmds.txt TRUE")
          tf.close
          expect { Target.new("TGT").process_file(tf.path) }.to raise_error(ConfigParser::Error, /Too many parameters for COMMANDS./)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("TELEMETRY")
          tf.close
          expect { Target.new("TGT").process_file(tf.path) }.to raise_error(ConfigParser::Error, /Not enough parameters for TELEMETRY./)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("TELEMETRY tgt_tlm.txt TRUE")
          tf.close
          expect { Target.new("TGT").process_file(tf.path) }.to raise_error(ConfigParser::Error, /Too many parameters for TELEMETRY./)
          tf.unlink
        end

        it "stores the filename" do
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
          expect(tgt.dir).to eql tgt_dir
          expect(tgt.cmd_tlm_files.length).to eql 2
          expect(tgt.cmd_tlm_files).to eql [tgt_dir + '/cmd_tlm/tgt_cmds2.txt', tgt_dir + '/cmd_tlm/tgt_tlm3.txt']

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

          expect { Target.new(tgt_name,nil,tgt_path) }.to raise_error(ConfigParser::Error, /#{tgt_dir + '/cmd_tlm/tgt_cmds4.txt'} not found/)

          FileUtils.rm_r(tgt_dir)
        end

        it "filename order must be preserved" do
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
            file.puts("COMMANDS tgt_cmds3.txt")
            file.puts("COMMANDS tgt_cmds2.txt")
            file.puts("TELEMETRY tgt_tlm3.txt")
            file.puts("TELEMETRY tgt_tlm.txt")
          end

          tgt = Target.new(tgt_name,nil,tgt_path)
          expect(tgt.dir).to eql tgt_dir
          expect(tgt.cmd_tlm_files.length).to eql 4
          expect(tgt.cmd_tlm_files).to eql [tgt_dir + '/cmd_tlm/tgt_cmds3.txt', tgt_dir + '/cmd_tlm/tgt_cmds2.txt', tgt_dir + '/cmd_tlm/tgt_tlm3.txt', tgt_dir + '/cmd_tlm/tgt_tlm.txt']

          FileUtils.rm_rf(tgt_dir)
        end
      end
    end

  end
end
