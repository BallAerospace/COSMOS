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
require 'cosmos/system/system'
require 'tempfile'
require 'fileutils'

module Cosmos

  describe System do
    before(:all) do
      clean_config()
      System.class_eval('@@instance = nil')

      # Save system.txt
      @config_file = File.join(Cosmos::USERPATH,'config','system','system.txt')
      FileUtils.mv @config_file, Cosmos::USERPATH

      # Create a dummy system.txt
      File.open(@config_file,'w') {|file| file.puts "# This is a comment" }
      @config_targets = File.join(Cosmos::USERPATH,'config','targets')
    end

    after(:all) do
      # Restore system.txt
      FileUtils.mv File.join(Cosmos::USERPATH, 'system.txt'),
        File.join(Cosmos::USERPATH,'config','system')
      System.class_eval('@@instance = nil')
    end

    after(:each) do
      clean_config()
      System.class_eval('@@instance = nil')
    end

    describe "instance" do
      it "creates default ports" do
        # Don't check the actual port numbers but just that they exist
        expect(System.ports.keys).to eql %w(CTS_API TLMVIEWER_API CTS_PREIDENTIFIED CTS_CMD_ROUTER REPLAY_API REPLAY_PREIDENTIFIED REPLAY_CMD_ROUTER DART_STREAM DART_DECOM)
      end

      it "creates default paths" do
        # Don't check the actual paths but just that they exist
        expect(System.paths.keys).to eql %w(LOGS TMP SAVED_CONFIG TABLES HANDBOOKS PROCEDURES SEQUENCES DART_DATA DART_LOGS)
      end

      context "initializing SYSTEM META" do
        before(:all) do
          FileUtils.mv(File.join(@config_targets, 'SYSTEM', 'cmd_tlm', 'meta_tlm.txt'), Dir.pwd)
        end
        after(:all) do
          FileUtils.mv(File.join(Dir.pwd, 'meta_tlm.txt'), File.join(@config_targets, 'SYSTEM', 'cmd_tlm'))
        end

        it "initializes the SYSTEM META with no definitions" do
          tlm = System.telemetry.packet("SYSTEM", "META")
          expect(tlm.read("PKTID")).to_not be_nil
          expect(tlm.read("CONFIG")).to_not be_nil
          expect(tlm.read("COSMOS_VERSION")).to_not be_nil
          expect(tlm.read("RUBY_VERSION")).to_not be_nil
          expect(tlm.read("USER_VERSION")).to_not be_nil
          expect(tlm.received_time.to_f).to be_within(1).of(Time.now.to_f)
          cmd = System.commands.packet("SYSTEM", "META")
          expect(cmd.read("PKTID")).to eql tlm.read("PKTID")
          expect(cmd.read("CONFIG")).to eql tlm.read("CONFIG")
          expect(cmd.read("COSMOS_VERSION")).to eql tlm.read("COSMOS_VERSION")
          expect(cmd.read("RUBY_VERSION")).to eql tlm.read("RUBY_VERSION")
          expect(cmd.read("USER_VERSION")).to eql tlm.read("USER_VERSION")
          expect(cmd.received_time.to_f).to be_within(1).of(Time.now.to_f)
        end

        it "defaults badly defined TELEMETRY SYSTEM META" do
          file = File.open(File.join(@config_targets, 'SYSTEM', 'cmd_tlm', 'meta_tlm.txt'), 'w')
          file.puts "TELEMETRY SYSTEM META BIG_ENDIAN"
          file.puts "APPEND_ID_ITEM PKTID 8 UINT 1"
          file.puts "APPEND_ITEM CONFIG 256 STRING"
          file.puts "APPEND_ITEM COSMOS_VERSION 240 STRING"
          file.puts "APPEND_ITEM USER_VERSION 240 STRING"
          file.puts "APPEND_ITEM RUBY_VERSION 200 STRING" # Error in the RUBY_VERSION length
          file.close

          expect(Logger).to receive(:error) do |msg|
            expect(msg).to eql "SYSTEM META not defined correctly due to RUBY_VERSION incorrect - defaulting"
          end
          tf = Tempfile.new('unittest')
          tf.puts("AUTO_DECLARE_TARGETS")
          tf.close
          System.class_variable_set(:@@instance, nil)
          System.new(tf.path)
          tlm = System.telemetry.packet("SYSTEM", "META")
          expect(tlm.read("RECEIVED_TIMESECONDS")).to_not be_nil
          expect(tlm.read("RECEIVED_TIMEFORMATTED")).to_not be_nil
          expect(tlm.read("RECEIVED_COUNT")).to_not be_nil
          expect(tlm.read("PKTID")).to_not be_nil
          expect(tlm.read("CONFIG")).to_not be_nil
          expect(tlm.read("COSMOS_VERSION")).to_not be_nil
          expect(tlm.get_item("COSMOS_VERSION").bit_size).to eql(240)
          expect(tlm.read("RUBY_VERSION")).to_not be_nil
          expect(tlm.read("USER_VERSION")).to_not be_nil
          cmd = System.commands.packet("SYSTEM", "META")
          expect(cmd.read("PKTID")).to eql tlm.read("PKTID")
          expect(cmd.read("CONFIG")).to eql tlm.read("CONFIG")
          expect(cmd.read("COSMOS_VERSION")).to eql tlm.read("COSMOS_VERSION")
          expect(cmd.read("RUBY_VERSION")).to eql tlm.read("RUBY_VERSION")
          expect(cmd.read("USER_VERSION")).to eql tlm.read("USER_VERSION")
          tf.unlink
        end

        it "doesn't allow COMMAND SYSTEM META definitions" do
          file = File.open(File.join(@config_targets, 'SYSTEM', 'cmd_tlm', 'meta_tlm.txt'), 'w')
          file.puts "TELEMETRY SYSTEM META BIG_ENDIAN"
          file.puts "APPEND_ID_ITEM PKTID 8 UINT 1"
          file.puts "APPEND_ITEM CONFIG 256 STRING"
          file.puts "APPEND_ITEM COSMOS_VERSION 240 STRING"
          file.puts "APPEND_ITEM USER_VERSION 240 STRING"
          file.puts "APPEND_ITEM RUBY_VERSION 240 STRING"
          file.puts "APPEND_ITEM TEST 512 STRING ''"
          # The command system meta definition is correct but not allowed
          file.puts "COMMAND SYSTEM META BIG_ENDIAN"
          file.puts "APPEND_ID_PARAMETER PKTID 8 UINT 1 1 1"
          file.puts "APPEND_PARAMETER CONFIG 256 STRING ''"
          file.puts "APPEND_PARAMETER COSMOS_VERSION 240 STRING ''"
          file.puts "APPEND_PARAMETER USER_VERSION 240 STRING ''"
          file.puts "APPEND_PARAMETER RUBY_VERSION 240 STRING ''"
          file.puts "APPEND_PARAMETER TEST 512 STRING ''"
          file.close

          expect(Logger).to receive(:error) do |msg|
            expect(msg).to eql "SYSTEM META not defined correctly due to COMMAND SYSTEM META defined - defaulting"
          end
          tf = Tempfile.new('unittest')
          tf.puts("AUTO_DECLARE_TARGETS")
          tf.close
          System.class_variable_set(:@@instance, nil)
          System.new(tf.path)
          tlm = System.telemetry.packet("SYSTEM", "META")
          expect(tlm.read("PKTID")).to_not be_nil
          expect(tlm.read("CONFIG")).to_not be_nil
          expect(tlm.read("COSMOS_VERSION")).to_not be_nil
          expect(tlm.get_item("COSMOS_VERSION").bit_size).to eql(240)
          expect(tlm.read("RUBY_VERSION")).to_not be_nil
          expect(tlm.read("USER_VERSION")).to_not be_nil
          expect(tlm.items.keys.include?("TEST")).to be false
          cmd = System.commands.packet("SYSTEM", "META")
          expect(cmd.read("PKTID")).to eql tlm.read("PKTID")
          expect(cmd.read("CONFIG")).to eql tlm.read("CONFIG")
          expect(cmd.read("COSMOS_VERSION")).to eql tlm.read("COSMOS_VERSION")
          expect(cmd.read("RUBY_VERSION")).to eql tlm.read("RUBY_VERSION")
          expect(cmd.read("USER_VERSION")).to eql tlm.read("USER_VERSION")
          expect(cmd.items.keys.include?("TEST")).to be false
          tf.unlink
        end

        it "defines COMMAND SYSTEM META based on TELEMETRY" do
          file = File.open(File.join(@config_targets, 'SYSTEM', 'cmd_tlm', 'meta_tlm.txt'), 'w')
          file.puts "TELEMETRY SYSTEM META BIG_ENDIAN"
          file.puts "APPEND_ID_ITEM PKTID 8 UINT 1"
          file.puts "APPEND_ITEM CONFIG 256 STRING"
          file.puts "APPEND_ITEM COSMOS_VERSION 240 STRING"
          file.puts "APPEND_ITEM USER_VERSION 240 STRING"
          file.puts "APPEND_ITEM RUBY_VERSION 240 STRING"
          file.puts "APPEND_ITEM TEST 240 STRING"
          file.close

          expect(Logger).to_not receive(:error)
          tf = Tempfile.new('unittest')
          tf.puts("AUTO_DECLARE_TARGETS")
          tf.close
          System.class_variable_set(:@@instance, nil)
          System.new(tf.path)
          tlm = System.telemetry.packet("SYSTEM", "META")
          expect(tlm.read("PKTID")).to_not be_nil
          expect(tlm.read("CONFIG")).to_not be_nil
          expect(tlm.read("COSMOS_VERSION")).to_not be_nil
          expect(tlm.read("RUBY_VERSION")).to_not be_nil
          expect(tlm.read("USER_VERSION")).to_not be_nil
          expect(tlm.read("TEST")).to_not be_nil
          cmd = System.commands.packet("SYSTEM", "META")
          expect(cmd.read("PKTID")).to eql tlm.read("PKTID")
          expect(cmd.read("CONFIG")).to eql tlm.read("CONFIG")
          expect(cmd.read("COSMOS_VERSION")).to eql tlm.read("COSMOS_VERSION")
          expect(cmd.read("RUBY_VERSION")).to eql tlm.read("RUBY_VERSION")
          expect(cmd.read("USER_VERSION")).to eql tlm.read("USER_VERSION")
          expect(cmd.read("TEST")).to eql tlm.read("TEST")
          tf.unlink
        end
      end
    end

    describe "System.commands" do
      it "is just SYSTEM" do
        expect(System.commands.target_names).to eql ['SYSTEM']
      end

      it "logs errors saving the configuration" do
       # Write the system.txt file to auto declare targets
       File.open(@config_file, 'w') { |file| file.puts "AUTO_DECLARE_TARGETS" }
       # Force a reload of the configuration
       System.class_eval('@@instance = nil')
       capture_io do |stdout|
         allow(Zip::File).to receive(:open) { raise "Error" }
         System.commands
         expect(stdout.string).to match("Problem saving configuration")
       end
       File.open(@config_file, 'w') { |file| file.puts "# Comment" }
      end
    end

    describe "System.telemetry" do
      it "is just SYSTEM" do
        expect(System.telemetry.target_names).to eql ['SYSTEM']
      end
    end

    describe "System.limits" do
      it "includes the DEFAULT limit set" do
        expect(System.limits.sets).to include :DEFAULT
      end
    end

    context "with valid targets" do
      before(:all) do
        # Write the system.txt file to auto declare targets
        File.open(@config_file,'w') { |file| file.puts "AUTO_DECLARE_TARGETS" }
      end

      describe "System.clear_counters" do
        it "clears the target, command and telemetry counters" do
          expect(System.targets.length).to be > 0
          System.targets.each do |name, tgt|
            tgt.cmd_cnt = 100
            tgt.tlm_cnt = 100
          end
          System.commands.all do |tgt, pkt|
            pkt.received_count = 100
          end
          System.telemetry.all do |tgt, pkt|
            pkt.received_count = 100
          end

          System.clear_counters

          System.targets.each do |name, tgt|
            expect(tgt.cmd_cnt).to eql 0
            expect(tgt.tlm_cnt).to eql 0
          end
          System.commands.all do |tgt, pkt|
            expect(pkt.received_count).to eql 0
          end
          System.telemetry.all do |tgt, pkt|
            expect(pkt.received_count).to eql 0
          end
        end
      end

      describe "packets and System.packets" do
        it "calculates hash strings across all the target files" do
          capture_io do |stdout|
            # This line actually does the work of reading the configuration
            expect(System.telemetry.target_names).to eql ['INST', 'SYSTEM']
            expect(System.commands.target_names).to eql ['INST', 'SYSTEM']

            expect(stdout.string).to match("Marshal file does not exist")

            # Reset stdout for another go at the processing
            stdout.rewind
            # Reset the instance variable so it will read the new configuration
            System.class_eval('@@instance = nil')
            # This line actually does the work of reading the configuration
            expect(System.telemetry.target_names).to eql ['INST', 'SYSTEM']
            expect(System.commands.target_names).to eql ['INST', 'SYSTEM']

            expect(stdout.string).to match("Marshal load success")
          end
        end

        it "handles target parsing errors" do
          capture_io do |stdout|
            allow_any_instance_of(PacketConfig).to receive(:process_file) { raise "ProcessError" }
            # This line actually does the work of reading the configuration
            expect { System.telemetry.target_names }.to raise_error("ProcessError")

            expect(stdout.string).to match("Problem processing")
          end
        end
      end

      describe "load_configuration" do
        after(:all) do
          test1 = File.join(@config_targets,'SYSTEM','cmd_tlm','test1_tlm.txt')
          FileUtils.rm_f(test1) if File.exist?(test1)
          test2 = File.join(@config_targets,'SYSTEM','cmd_tlm','test2_tlm.txt')
          FileUtils.rm_f(test2) if File.exist?(test2)
        end

        it "loads the initial configuration" do
          System.load_configuration
          expect(System.commands.target_names).to eql ['INST', 'SYSTEM']
          expect(System.telemetry.target_names).to eql ['INST', 'SYSTEM']
        end

        it "loads a named configuration" do
          File.open(@config_file,'w') do |file|
            file.puts "DECLARE_TARGET INST OVERRIDE"
            file.puts "DECLARE_TARGET SYSTEM"
          end

          # Load the original configuration
          original_config_name, err = System.load_configuration
          expect(err).to eql nil
          expect(System.telemetry.target_names).to eql %w(OVERRIDE SYSTEM)
          System.telemetry.packets('SYSTEM').keys

          # Create a new configuration by writing another telemetry file
          File.open(File.join(@config_targets,'SYSTEM','cmd_tlm','test1_tlm.txt'),'w') do |file|
            file.puts "TELEMETRY SYSTEM TEST1 BIG_ENDIAN"
            file.puts "  APPEND_ITEM DATA 240 STRING"
          end
          System.instance.process_file(@config_file)
          # Verify the new telemetry packet is there
          expect(System.telemetry.packets('SYSTEM').keys).to include "TEST1"
          second_config_name = System.configuration_name

          # Now load the original configuration
          name, err = System.load_configuration(original_config_name)
          expect(err).to eql nil
          expect(original_config_name).to eql name
          expect(System.telemetry.packets('SYSTEM').keys).not_to include "TEST1"

          # Create yet another configuration by writing another telemetry file
          File.open(File.join(@config_targets,'SYSTEM','cmd_tlm','test2_tlm.txt'),'w') do |file|
            file.puts "TELEMETRY SYSTEM TEST2 BIG_ENDIAN"
            file.puts "  APPEND_ITEM DATA 240 STRING"
          end
          System.instance.process_file(@config_file)
          # Verify the new telemetry packet is there as well as the second one
          expect(System.telemetry.packets('SYSTEM').keys).to include("TEST1", "TEST2")
          #third_config_name = System.configuration_name

          # Try loading something that doesn't exist
          # It should fail and reload the original configuration
          name, err = System.load_configuration("BLAH")
          expect(err).to eql nil
          expect(name).to eql original_config_name

          # Now load the second configuration. It shouldn't have the most
          # recently defined telemetry packet.
          System.load_configuration(second_config_name)
          expect(System.telemetry.packets('SYSTEM').keys).to include "TEST1"
          expect(System.telemetry.packets('SYSTEM').keys).not_to include "TEST2"

          # Now remove system.txt from the third configuration and try to load it again to cause an error
          #third_config_path = System.instance.send(:find_configuration, third_config_name)
          #FileUtils.mv File.join(third_config_path, 'system.txt'), File.join(third_config_path, 'system2.txt')
          #result, err = System.load_configuration(third_config_name)
          #expect(result).to eql original_config_name
          #expect(err).to_not be_nil
        end
      end
    end

    describe "process_file" do
      before(:all) do
        begin
          # Move the targets directory out of the way so we can make our own
          FileUtils.mv @config_targets, Cosmos::USERPATH
          FileUtils.mkdir_p(@config_targets)
          File.open(@config_file,'w') { |file| file.puts "AUTO_DECLARE_TARGETS" }
        rescue
          puts "Cannot move targets folder... probably due to open editor or explorer"
          exit 1
        end
      end
      after(:all) do
        # Restore the targets directory
        FileUtils.rm_rf @config_targets
        FileUtils.mv File.join(Cosmos::USERPATH, 'targets'), File.join(Cosmos::USERPATH, 'config')
      end

      it "complains about unknown keywords" do
        tf = Tempfile.new('unittest')
        tf.puts("BLAH")
        tf.close
        expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Unknown keyword 'BLAH'/)
        tf.unlink
      end

      context "with AUTO_DECLARE_TARGETS" do
        it "takes 0 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("AUTO_DECLARE_TARGETS TRUE")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Too many parameters for AUTO_DECLARE_TARGETS./)
          tf.unlink
        end

        it "complains if config/targets doesn't exist" do
          tf = Tempfile.new('unittest')
          tf.puts("AUTO_DECLARE_TARGETS")
          tf.close
          FileUtils.rm_rf(@config_targets)
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /\/config\/targets must exist/)
          FileUtils.mkdir_p(@config_targets)
          tf.unlink
        end

        it "complains if target directories aren't uppercase" do
          tf = Tempfile.new('unittest')
          tf.puts("AUTO_DECLARE_TARGETS")
          tf.close
          FileUtils.mkdir_p(File.join(@config_targets, 'tgt'))
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Target folder must be uppercase: 'tgt'/)
          Dir.rmdir(File.join(@config_targets, 'tgt'))
          tf.unlink
        end

        it "processes target directories with the SYSTEM directory last" do
          tf = Tempfile.new('unittest')
          tf.puts("AUTO_DECLARE_TARGETS")
          tf.close
          FileUtils.mkdir_p(File.join(@config_targets, 'ABC'))
          FileUtils.mkdir_p(File.join(@config_targets, 'SYSTEM'))
          FileUtils.mkdir_p(File.join(@config_targets, 'XYZ'))
          System.instance.process_file(tf.path)
          # Since Ruby 1.9+ uses ordered Hashes we can ask for the keys and
          # SYSTEM should be last
          expect(System.instance.targets.keys).to eql %w(ABC XYZ SYSTEM)
          Dir.rmdir(File.join(@config_targets, 'ABC'))
          Dir.rmdir(File.join(@config_targets, 'SYSTEM'))
          Dir.rmdir(File.join(@config_targets, 'XYZ'))
          tf.unlink
        end

        it "ignores previous DECLARE_TARGET directories" do
          tf = Tempfile.new('unittest')
          tf.puts("DECLARE_TARGET ABC CBA")
          tf.puts("AUTO_DECLARE_TARGETS")
          tf.close
          FileUtils.mkdir_p(File.join(@config_targets, 'ABC'))
          FileUtils.mkdir_p(File.join(@config_targets, 'SYSTEM'))
          FileUtils.mkdir_p(File.join(@config_targets, 'XYZ'))
          System.instance.process_file(tf.path)
          # Since Ruby 1.9+ uses ordered Hashes we can ask for the keys and
          # SYSTEM should be last
          expect(System.instance.targets.keys).to eql %w(CBA XYZ SYSTEM)
          Dir.rmdir(File.join(@config_targets, 'ABC'))
          Dir.rmdir(File.join(@config_targets, 'SYSTEM'))
          Dir.rmdir(File.join(@config_targets, 'XYZ'))
          tf.unlink
        end
      end

      context "with DECLARE_TARGET" do
        it "takes 1 or 2 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("DECLARE_TARGET")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Not enough parameters for DECLARE_TARGET./)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("DECLARE_TARGET TGT TGT TGT TGT")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Too many parameters for DECLARE_TARGET./)
          tf.unlink
        end

        it "complains if the target directory doesn't exist" do
          tf = Tempfile.new('unittest')
          tf.puts("DECLARE_TARGET TGT")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Target folder must exist/)
          tf.unlink
        end

        it "processes the target directory" do
          tf = Tempfile.new('unittest')
          tf.puts("DECLARE_TARGET TGT")
          tf.close
          FileUtils.mkdir_p(File.join(@config_targets, 'TGT'))
          System.instance.process_file(tf.path)
          expect(System.targets.key?('TGT')).to be true
          expect(System.targets.key?('SYSTEM')).to be true
          tf.unlink
        end

        it "processes the target directory with substitute name" do
          tf = Tempfile.new('unittest')
          tf.puts("DECLARE_TARGET TGT NEW")
          tf.close
          FileUtils.mkdir_p(File.join(@config_targets, 'TGT'))
          System.instance.process_file(tf.path)
          tf.unlink
        end

        it "processes the target directory with specified target.txt" do
          tf = Tempfile.new('unittest')
          tf.puts("DECLARE_TARGET TGT nil target.txt")
          tf.close
          FileUtils.mkdir_p(File.join(@config_targets, 'TGT'))
          File.open(File.join(@config_targets, 'TGT', 'target.txt'), 'w') do |file|
            file.puts "# target.txt"
          end
          System.instance.process_file(tf.path)
          tf.unlink
        end
      end

      context "with PORT" do
        it "takes 2 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("PORT CTS_API")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Not enough parameters for PORT./)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("PORT CTS_API 8888 TRUE")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Too many parameters for PORT./)
          tf.unlink
        end

        it "complains about unknown ports" do
          tf = Tempfile.new('unittest')
          tf.puts("PORT MYPORT 10")
          tf.close
          capture_io do |stdout|
            System.instance.process_file(tf.path)
            expect(stdout.string).to match(/WARN: Unknown port name given: MYPORT/)
          end
          tf.unlink
        end

        it "changes known ports" do
          tf = Tempfile.new('unittest')
          tf.puts("PORT CTS_API 8888")
          tf.close
          expect(System.ports['CTS_API']).to eql 7777
          System.instance.process_file(tf.path)
          expect(System.ports['CTS_API']).to eql 8888
          tf.unlink
        end
      end

      context "with PATH" do
        it "takes 2 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("PATH C:/")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Not enough parameters for PATH./)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("PATH MYPATH C:/ TRUE")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Too many parameters for PATH./)
          tf.unlink
        end

        it "complains about unknown paths" do
          tf = Tempfile.new('unittest')
          tf.puts("PATH MYPATH C:/")
          tf.close
          capture_io do |stdout|
            System.instance.process_file(tf.path)
            expect(stdout.string).to match(/WARN: Unknown path name given: MYPATH/)
          end
          tf.unlink
        end

        it "changes known paths" do
          if Kernel.is_windows?
            tf = Tempfile.new('unittest')
            tf.puts("PATH LOGS C:/mylogs")
            tf.close
            expect(System.paths['LOGS']).to match('outputs/logs')
            System.instance.process_file(tf.path)
            expect(System.paths['LOGS']).to eql 'C:/mylogs'
            tf.unlink
          end
        end
      end

      context "with DEFAULT_PACKET_LOG_WRITER" do
        it "takes 1 or more parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("DEFAULT_PACKET_LOG_WRITER")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Not enough parameters for DEFAULT_PACKET_LOG_WRITER./)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("DEFAULT_PACKET_LOG_WRITER packet_log_writer.rb nil false")
          tf.close
          System.instance.process_file(tf.path)
          expect(System.default_packet_log_writer).to eql PacketLogWriter
          expect(System.default_packet_log_writer_params).to eql ["nil", "false"]
          tf.unlink
        end

        it "complains if the class doesn't exist" do
          tf = Tempfile.new('unittest')
          tf.puts("DEFAULT_PACKET_LOG_WRITER my_nonexistent_class")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(/Unable to require my_nonexistent_class/)
          tf.unlink
        end

        it "sets the packet writer" do
          filename = File.join(File.dirname(__FILE__),'..','..','lib','my_writer.rb')
          File.open(filename, 'w') do |file|
            file.puts "class MyWriter"
            file.puts "end"
          end
          tf = Tempfile.new('unittest')
          tf.puts("DEFAULT_PACKET_LOG_WRITER my_writer")
          tf.close
          System.instance.process_file(tf.path)
          expect(System.default_packet_log_writer).to eql MyWriter
          File.delete filename
          tf.unlink
        end
      end

      context "with DEFAULT_PACKET_LOG_READER" do
        it "takes 1 or more parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("DEFAULT_PACKET_LOG_READER")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Not enough parameters for DEFAULT_PACKET_LOG_READER./)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("DEFAULT_PACKET_LOG_READER packet_log_reader.rb nil false")
          tf.close
          System.instance.process_file(tf.path)
          expect(System.default_packet_log_reader).to eql PacketLogReader
          expect(System.default_packet_log_reader_params).to eql ["nil", "false"]
          tf.unlink
        end

        it "complains if the class doesn't exist" do
          tf = Tempfile.new('unittest')
          tf.puts("DEFAULT_PACKET_LOG_READER my_nonexistent_class")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(/Unable to require my_nonexistent_class/)
          tf.unlink
        end

        it "sets the packet reader" do
          filename = File.join(File.dirname(__FILE__),'..','..','lib','my_reader.rb')
          File.open(filename, 'w') do |file|
            file.puts "class MyReader"
            file.puts "end"
          end
          tf = Tempfile.new('unittest')
          tf.puts("DEFAULT_PACKET_LOG_READER my_reader")
          tf.close
          System.instance.process_file(tf.path)
          expect(System.default_packet_log_reader).to eql MyReader
          File.delete filename
          tf.unlink
        end
      end

      context "with DISABLE_DNS" do
        it "takes 0 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("DISABLE_DNS BLAH TRUE")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Too many parameters for DISABLE_DNS./)
          tf.unlink
        end

        it "disables dns lookups" do
          tf = Tempfile.new('unittest')
          tf.puts("DISABLE_DNS")
          tf.close
          expect(System.use_dns).to be false
          System.instance.process_file(tf.path)
          expect(System.use_dns).to be false
          tf.unlink
        end

        it "enables dns lookups" do
          tf = Tempfile.new('unittest')
          tf.puts("ENABLE_DNS")
          tf.close
          expect(System.use_dns).to be false
          System.instance.process_file(tf.path)
          expect(System.use_dns).to be true
          tf.unlink
        end
      end

      context "with ALLOW_ACCESS" do
        it "takes 1 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("ALLOW_ACCESS")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Not enough parameters for ALLOW_ACCESS./)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("ALLOW_ACCESS localhost true")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Too many parameters for ALLOW_ACCESS./)
          tf.unlink
        end

        it "complains about bad addresses" do
          tf = Tempfile.new('unittest')
          tf.puts("ALLOW_ACCESS blah")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("ALLOW_ACCESS hopefully_this_is_not_a_valid_machine_name_XYZ")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error)
          tf.unlink
        end

        it "allows ALL" do
          tf = Tempfile.new('unittest')
          tf.puts("ALLOW_ACCESS ALL")
          tf.close
          System.instance.process_file(tf.path)
          expect(System.acl).to be_nil
          tf.unlink
        end

        it "stores host by name" do
          tf = Tempfile.new('unittest')
          tf.puts("ALLOW_ACCESS localhost")
          tf.close
          System.instance.process_file(tf.path)
          expect(System.acl.allow_addr?(["AF_INET",0,"localhost","127.0.0.1"])).to be true
          tf.unlink
        end

        it "stores host by IP address" do
          addr = IPSocket.getaddress("www.google.com")
          if addr and !addr.index(':')
            tf = Tempfile.new('unittest')
            tf.puts("ALLOW_ACCESS #{addr}")
            tf.close
            System.instance.process_file(tf.path)
            expect(System.acl.allow_addr?(["AF_INET",0,"www.google.com",addr])).to be true
            tf.unlink
          end
        end
      end

      context "with STALENESS_SECONDS" do
        it "takes 1 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("STALENESS_SECONDS")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Not enough parameters for STALENESS_SECONDS./)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("STALENESS_SECONDS 1 2")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Too many parameters for STALENESS_SECONDS./)
          tf.unlink
        end

        it "sets the number of seconds required to be stale" do
          tf = Tempfile.new('unittest')
          tf.puts("STALENESS_SECONDS 3")
          tf.close
          expect(System.staleness_seconds).to eql 30
          System.instance.process_file(tf.path)
          expect(System.staleness_seconds).to eql 3
          tf.unlink
        end
      end

      context "with META_INIT" do
        it "takes 1 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("META_INIT")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Not enough parameters for META_INIT./)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("META_INIT 1 2")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Too many parameters for META_INIT./)
          tf.unlink
        end

        it "populates the SYSTEM META packet with the file" do
          FileUtils.rm_rf @config_targets
          FileUtils.mkdir_p(File.join(@config_targets, 'SYSTEM', 'cmd_tlm'))
          file = File.open(File.join(@config_targets, 'SYSTEM', 'cmd_tlm', 'meta_tlm.txt'), 'w')
          file.puts "TELEMETRY SYSTEM META BIG_ENDIAN"
          file.puts "APPEND_ID_ITEM PKTID 8 UINT 1"
          file.puts "APPEND_ITEM CONFIG 256 STRING"
          file.puts "APPEND_ITEM COSMOS_VERSION 240 STRING"
          file.puts "APPEND_ITEM USER_VERSION 240 STRING"
          file.puts "APPEND_ITEM RUBY_VERSION 240 STRING"
          file.puts "APPEND_ITEM TEST 512 STRING"
          file.puts "APPEND_ITEM ID 32 UINT"
          file.close

          meta = Tempfile.new('meta')
          meta.puts("USER_VERSION 4.5")
          meta.puts("TEST hello")
          meta.puts("ID 123456789")
          meta.close
          tf = Tempfile.new('unittest')
          tf.puts("AUTO_DECLARE_TARGETS")
          tf.puts("META_INIT #{meta.path}")
          tf.close
          System.class_variable_set(:@@instance, nil)
          System.new(tf.path)
          tlm = System.telemetry.packet("SYSTEM", "META")
          expect(tlm.read("USER_VERSION")).to eql '4.5'
          expect(tlm.read("TEST")).to eql 'hello'
          expect(tlm.read("ID")).to eql 123456789
          cmd = System.commands.packet("SYSTEM", "META")
          expect(cmd.read("USER_VERSION")).to eql tlm.read("USER_VERSION")
          expect(cmd.read("TEST")).to eql tlm.read("TEST")
          expect(cmd.read("ID")).to eql tlm.read("ID")
          tf.unlink
          meta.unlink
          FileUtils.rm_rf(File.join(@config_targets, 'SYSTEM'))
        end
      end

      context "with ADD_MD5_FILE" do
        it "takes 1 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("ADD_MD5_FILE")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Not enough parameters for ADD_MD5_FILE./)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("ADD_MD5_FILE 1 2")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Too many parameters for ADD_MD5_FILE./)
          tf.unlink
        end

        it "complains about missing files" do
          tf = Tempfile.new('unittest')
          tf.puts("ADD_MD5_FILE missing_file")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(/Missing expected file: missing_file/)
          tf.unlink
        end

        it "adds a file to the MD5 calculation" do
          md5f = Tempfile.new('md5_file')
          tf = Tempfile.new('unittest')
          tf.puts("ADD_MD5_FILE #{File.expand_path(md5f.path)}")
          tf.close
          System.instance.process_file(tf.path)
          expect(System.additional_hashing_files.include?(File.expand_path(md5f.path))).to be true
          md5f.close
          md5f.unlink
          tf.unlink
        end
      end

      context "with ADD_HASH_FILE" do
        it "takes 1 parameter" do
          tf = Tempfile.new('unittest')
          tf.puts("ADD_HASH_FILE")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Not enough parameters for ADD_HASH_FILE./)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("ADD_HASH_FILE 1 2")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Too many parameters for ADD_HASH_FILE./)
          tf.unlink
        end

        it "complains about missing files" do
          tf = Tempfile.new('unittest')
          tf.puts("ADD_HASH_FILE missing_file")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(/Missing expected file: missing_file/)
          tf.unlink
        end

        it "adds a file to the hashing sum calculation" do
          hashf = Tempfile.new('hash_file')
          tf = Tempfile.new('unittest')
          tf.puts("ADD_HASH_FILE #{File.expand_path(hashf.path)}")
          tf.close
          System.instance.process_file(tf.path)
          expect(System.additional_hashing_files.include?(File.expand_path(hashf.path))).to be true
          hashf.close
          hashf.unlink
          tf.unlink
        end
      end

      context "with HASHING_ALGORITHM" do
        it "takes 1 parameter" do
          tf = Tempfile.new('unittest')
          tf.puts("HASHING_ALGORITHM")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Not enough parameters for HASHING_ALGORITHM./)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("HASHING_ALGORITHM 1 2")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Too many parameters for HASHING_ALGORITHM./)
          tf.unlink
        end

        it "complains about invalid algorithms" do
          tf = Tempfile.new('unittest')
          tf.puts("HASHING_ALGORITHM BAD")
          tf.close
          expect(Logger).to receive(:error) do |msg|
            expect(msg).to eql "Unrecognized hashing algorithm: BAD, using default algorithm MD5"
          end
          System.instance.process_file(tf.path)
          expect(System.hashing_algorithm).to eql 'MD5'
          tf.unlink
        end

        it "sets the hashing algorithm" do
          tf = Tempfile.new('unittest')
          tf.puts("HASHING_ALGORITHM SHA256")
          tf.close
          System.instance.process_file(tf.path)
          expect(System.hashing_algorithm).to eql 'SHA256'
          tf.unlink
        end
      end
    end

    describe "Cosmos.write_exception_file" do
      it "writes a file with the exception" do
        filename = Cosmos.write_exception_file(RuntimeError.new("HELP!"))
        expect(File.exist?(filename)).to be true
        File.delete(filename)
      end

      it "writes a file without a defined LOGS directory" do
        File.open(@config_file,'w') {|file| file.puts "PATH LOGS C:/this/is/not/a/real/path" }
        # Reset the instance variable so it will read the new config file
        System.instance_eval('@instance = nil')
        filename = Cosmos.write_exception_file(RuntimeError.new("HELP!"))
        expect(File.exist?(filename)).to be true
        File.delete(filename)
      end
    end
  end
end
