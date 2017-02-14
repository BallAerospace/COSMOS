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

        tgt = Target.new(tgt_name,nil,tgt_path)
        expect(tgt.dir).to eql File.join(tgt_path,tgt_name)
        files = Dir[File.join(cmd_tlm,'*.txt')]
        expect(files).not_to be_empty
        expect(tgt.cmd_tlm_files.length).to eql 4
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
          expect { Target.new("TGT").process_file(tf.path) }.to raise_error(ConfigParser::Error, /Not enough parameters for REQUIRE./)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("REQUIRE my_file.rb TRUE")
          tf.close
          expect { Target.new("TGT").process_file(tf.path) }.to raise_error(ConfigParser::Error, /Too many parameters for REQUIRE./)
          tf.unlink
        end

        it "complains if the file doesn't exist" do
          tf = Tempfile.new('unittest')
          tf.puts("REQUIRE my_file.rb")
          tf.close
          expect { Target.new("TGT").process_file(tf.path) }.to raise_error(LoadError, /Unable to require my_file.rb/)
          tf.unlink
        end

        it "requires a file in lib" do
          filename = File.join(Cosmos::USERPATH, 'lib', 'my_file.rb')
          File.open(filename, 'w') do |file|
            file.puts "class MyFile"
            file.puts "  CONST = 6"
            file.puts "end"
          end
          tf = Tempfile.new('unittest')
          tf.puts("REQUIRE my_file.rb")
          tf.close
          Target.new("TGT").process_file(tf.path)
          expect(MyFile::CONST).to eql 6
          File.delete filename
          tf.unlink
        end

        it "allows system lib to override target lib" do
          tgt_lib_dir = File.join(Cosmos::USERPATH, 'config', 'targets', 'TEST', 'lib')
          FileUtils.mkdir_p(tgt_lib_dir)
          tgt_filename = File.join(tgt_lib_dir, 'tgt_file.rb')
          File.open(tgt_filename, 'w') do |file|
            file.puts "class TgtFile"
            file.puts "  def self.location; 'tgt'; end"
            file.puts "end"
          end
          lib_filename = File.join(Cosmos::USERPATH, 'lib', 'tgt_file.rb')
          File.open(lib_filename, 'w') do |file|
            file.puts "module Cosmos; module TEST; class TgtFile"
            file.puts "  def self.location; 'lib'; end"
            file.puts "end; end; end"
          end

          tf = Tempfile.new('unittest')
          tf.puts("REQUIRE tgt_file.rb")
          tf.close
          Target.new("TEST").process_file(tf.path)
          expect(TEST::TgtFile.location).to eql 'lib'
          File.delete lib_filename
          FileUtils.rm_rf File.join(tgt_lib_dir, '..')
          tf.unlink
        end

        it "namespaces files in target lib" do
          lib_filename = File.join(Cosmos::USERPATH, 'lib', 'lib_file.rb')
          File.open(lib_filename, 'w') do |file|
            file.puts "class LibFile"
            file.puts "  def self.location; 'lib'; end"
            file.puts "end"
          end

          tgt_lib_dir = File.join(Cosmos::USERPATH, 'config', 'targets', 'TEST', 'lib')
          FileUtils.mkdir_p(tgt_lib_dir)
          tgt_filename = File.join(tgt_lib_dir, 'tgt_file.rb')
          File.open(tgt_filename, 'w') do |file|
            file.puts "require 'lib_file.rb'" # Verify we can require & use files in lib
            file.puts "class TgtFile"
            file.puts "  def self.location; LibFile.location + 'test'; end"
            file.puts "end"
          end
          tgt2_lib_dir = File.join(Cosmos::USERPATH, 'config', 'targets', 'TEST2', 'lib')
          FileUtils.mkdir_p(tgt2_lib_dir)
          tgt2_filename = File.join(tgt2_lib_dir, 'tgt_file.rb')
          File.open(tgt2_filename, 'w') do |file|
            file.puts "class TgtFile"
            file.puts "  def self.location; 'test2'; end"
            file.puts "end"
          end
          tgt2_filename = File.join(tgt2_lib_dir, 'tgt2_file.rb')
          File.open(tgt2_filename, 'w') do |file|
            file.puts "class TgtFile" # Override the original
            file.puts "  def self.location; 'test22'; end"
            file.puts "end"
          end

          tf1 = Tempfile.new('unittest')
          tf1.puts("REQUIRE tgt_file.rb")
          tf1.close
          tf2 = Tempfile.new('unittest')
          tf2.puts("REQUIRE tgt_file.rb")
          tf2.puts("REQUIRE tgt2_file.rb")
          tf2.close
          Target.new("TEST").process_file(tf1.path)
          expect(TEST::TgtFile.location).to eql 'libtest'
          Target.new("TEST2").process_file(tf2.path)
          expect(TEST2::TgtFile.location).to eql 'test22'
          FileUtils.rm_rf File.join(tgt_lib_dir, '..')
          FileUtils.rm_rf File.join(tgt2_lib_dir, '..')
          File.delete lib_filename
          tf1.unlink
          tf2.unlink
        end

        it "allows target lib files to be used in cmd/tlm" do
          tgt_dir = File.join(Cosmos::USERPATH, 'config', 'targets', 'TEST')
          FileUtils.mkdir_p(tgt_dir)
          File.open(File.join(tgt_dir,'target.txt'),'w') do |file|
            file.puts("REQUIRE my_conversion.rb")
            file.puts("REQUIRE my_response.rb")
            file.puts("REQUIRE my_processor.rb")
          end

          tgt_lib_dir = File.join(tgt_dir, 'lib')
          FileUtils.mkdir_p(tgt_lib_dir)
          conversion_filename = File.join(tgt_lib_dir, 'my_conversion.rb')
          File.open(conversion_filename, 'w') do |file|
            file.puts "require 'cosmos/conversions/conversion'"
            file.puts "class MyConversion < Cosmos::Conversion"
            file.puts "  def call(value, packet, buffer)"
            file.puts "    value * 2"
            file.puts "  end"
            file.puts "end"
          end
          response_filename = File.join(tgt_lib_dir, 'my_response.rb')
          File.open(response_filename, 'w') do |file|
            file.puts "require 'cosmos/packets/limits_response'"
            file.puts "class MyResponse < Cosmos::LimitsResponse"
            file.puts "  def call(packet, item, old_limits_state); end"
            file.puts "end"
          end
          processor_filename = File.join(tgt_lib_dir, 'my_processor.rb')
          File.open(processor_filename, 'w') do |file|
            file.puts "require 'cosmos/processors/processor'"
            file.puts "class MyProcessor < Cosmos::Processor"
            file.puts "  def call(packet, buffer); end"
            file.puts "end"
          end
          tgt_cmdtlm_dir = File.join(tgt_dir, 'cmd_tlm')
          FileUtils.mkdir_p(tgt_cmdtlm_dir)
          tlm_filename = File.join(tgt_cmdtlm_dir, 'tlm.txt')
          File.open(tlm_filename, 'w') do |file|
            file.puts "TELEMETRY TEST DATA BIG_ENDIAN \"Description\""
            file.puts "APPEND_ITEM ITEM1 8 UINT \"Ground station #2 status\""
            file.puts "  READ_CONVERSION my_conversion.rb"
            file.puts "  LIMITS_RESPONSE my_response.rb"
            file.puts "  PROCESSOR MyProcessor my_processor.rb"
          end

          target = Target.new("TEST")
          config = PacketConfig.new
          commands = Commands.new(config)
          telemetry = Telemetry.new(config)
          limits = Limits.new(config)
          target.cmd_tlm_files.each do |cmd_tlm_file|
            config.process_file(cmd_tlm_file, target.name)
          end
          packet = telemetry.packet("TEST", "DATA")
          packet.buffer = "\x01" # 1 should be read out as 2 due to conversion
          expect(packet.read("ITEM1")).to eq 2
          FileUtils.rm_rf tgt_dir
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

          FileUtils.rm_r(tgt_dir)
        end
      end
    end

  end
end

