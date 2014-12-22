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
require 'cosmos/system/system'
require 'tempfile'

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
    end

    after(:each) do
      clean_config()
      System.class_eval('@@instance = nil')
    end

    describe "instance" do
      it "should create default ports" do
        # Don't check the actual port numbers but just that they exist
        System.ports.keys.should eql %w(CTS_API TLMVIEWER_API CTS_PREIDENTIFIED)
      end

      it "should create default paths" do
        # Don't check the actual paths but just that they exist
        System.paths.keys.should eql %w(LOGS TMP SAVED_CONFIG TABLES HANDBOOKS PROCEDURES)
      end
    end

    describe "System.commands" do
      it "should only contain UNKNOWN" do
        System.commands.target_names.should eql ["UNKNOWN"]
      end

      it "should log errors saving the configuration" do
        # Force a reload of the configuration
        System.class_eval('@@instance = nil')

        capture_io do |stdout|
          allow(FileUtils).to receive(:mkdir_p) { raise "Error" }
          System.commands.target_names.should eql ["UNKNOWN"]
          stdout.string.should match "Problem saving configuration"
        end
      end
    end

    describe "System.telemetry" do
      it "should only contain UNKNOWN" do
        System.telemetry.target_names.should eql ["UNKNOWN"]
      end
    end

    describe "System.limits" do
      it "should include the DEFAULT limit set" do
        System.limits.sets.should include :DEFAULT
      end
    end

    context "with valid targets" do
      before(:all) do
        # Write the system.txt file to auto declare targets
        File.open(@config_file,'w') { |file| file.puts "AUTO_DECLARE_TARGETS" }
      end

      describe "System.clear_counters" do
        it "should clear the target, command and telemetry counters" do
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
            tgt.cmd_cnt.should eql 0
            tgt.tlm_cnt.should eql 0
          end
          System.commands.all do |tgt, pkt|
            pkt.received_count.should eql 0
          end
          System.telemetry.all do |tgt, pkt|
            pkt.received_count.should eql 0
          end
        end
      end

      describe "packets and System.packets" do
        it "should calculate MD5s across all the target files" do
          capture_io do |stdout|
            # This line actually does the work of reading the configuration
            System.telemetry.target_names.should eql ['COSMOS','INST','META','UNKNOWN']
            System.commands.target_names.should eql ['COSMOS','INST','META','UNKNOWN']

            stdout.string.should match "Marshal file does not exist"

            # Reset stdout for another go at the processing
            stdout.rewind
            # Reset the instance variable so it will read the new configuration
            System.class_eval('@@instance = nil')
            # This line actually does the work of reading the configuration
            System.telemetry.target_names.should eql ['COSMOS','INST','META','UNKNOWN']
            System.commands.target_names.should eql ['COSMOS','INST','META','UNKNOWN']

            stdout.string.should match "Marshal load success"
          end
        end

        it "should handle target parsing errors" do
          capture_io do |stdout|
            allow_any_instance_of(PacketConfig).to receive(:process_file) { raise "ProcessError" }
            # This line actually does the work of reading the configuration
            expect { System.telemetry.target_names.should eql ['COSMOS','INST','META','UNKNOWN'] }.to raise_error("ProcessError")

            stdout.string.should match "Problem processing"
          end
        end
      end

      describe "load_configuration" do
        after(:all) do
          File.delete(File.join(@config_targets,'COSMOS','cmd_tlm','test1_tlm.txt'))
          File.delete(File.join(@config_targets,'COSMOS','cmd_tlm','test2_tlm.txt'))
        end

        it "should load the initial configuration" do
          System.load_configuration
          System.commands.target_names.should eql ['COSMOS','INST','META','UNKNOWN']
          System.telemetry.target_names.should eql ['COSMOS','INST','META','UNKNOWN']
        end

        it "should load a named configuration" do
          File.open(@config_file,'w') do |file|
            file.puts "DECLARE_TARGET COSMOS"
            file.puts "DECLARE_TARGET COSMOS OVERRIDE"
          end

          # Load the original configuration
          original_config_name = System.load_configuration()
          System.telemetry.target_names.should eql %w(COSMOS OVERRIDE UNKNOWN)
          original_pkts = System.telemetry.packets('COSMOS').keys

          # Create a new configuration by writing another telemetry file
          File.open(File.join(@config_targets,'COSMOS','cmd_tlm','test1_tlm.txt'),'w') do |file|
            file.puts "TELEMETRY COSMOS TEST1 BIG_ENDIAN"
            file.puts "  APPEND_ITEM DATA 240 STRING"
          end
          System.instance.process_file(@config_file)
          # Verify the new telemetry packet is there
          System.telemetry.packets('COSMOS').keys.should include "TEST1"
          second_config_name = System.configuration_name

          # Now load the original configuration
          name = System.load_configuration(original_config_name)
          original_config_name.should eql name
          System.telemetry.packets('COSMOS').keys.should_not include "TEST1"

          # Create yet another configuration by writing another telemetry file
          File.open(File.join(@config_targets,'COSMOS','cmd_tlm','test2_tlm.txt'),'w') do |file|
            file.puts "TELEMETRY COSMOS TEST2 BIG_ENDIAN"
            file.puts "  APPEND_ITEM DATA 240 STRING"
          end
          System.instance.process_file(@config_file)
          names = []
          # Verify the new telemetry packet is there as well as the second one
          System.telemetry.packets('COSMOS').keys.should include("TEST1", "TEST2")
          third_config_name = System.configuration_name

          # Try loading something that doesn't exist
          # It should fail and reload the original configuration
          name = System.load_configuration("BLAH")
          name.should eql original_config_name

          # Now load the second configuration. It shouldn't have the most
          # recently defined telemetry packet.
          System.load_configuration(second_config_name)
          System.telemetry.packets('COSMOS').keys.should include "TEST1"
          System.telemetry.packets('COSMOS').keys.should_not include "TEST2"
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

      it "should complain about unknown keywords" do
        tf = Tempfile.new('unittest')
        tf.puts("BLAH")
        tf.close
        expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Unknown keyword 'BLAH'")
        tf.unlink
      end

      context "with AUTO_DECLARE_TARGETS" do
        it "should take 0 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("AUTO_DECLARE_TARGETS TRUE")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for AUTO_DECLARE_TARGETS.")
          tf.unlink
        end

        it "should complain if config/targets doesn't exist" do
          tf = Tempfile.new('unittest')
          tf.puts("AUTO_DECLARE_TARGETS")
          tf.close
          FileUtils.rm_rf(@config_targets)
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /\/config\/targets must exist/)
          FileUtils.mkdir_p(@config_targets)
          tf.unlink
        end

        it "should complain if target directories aren't uppercase" do
          tf = Tempfile.new('unittest')
          tf.puts("AUTO_DECLARE_TARGETS")
          tf.close
          FileUtils.mkdir_p(File.join(@config_targets, 'tgt'))
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Target folder must be uppercase: 'tgt'")
          Dir.rmdir(File.join(@config_targets, 'tgt'))
          tf.unlink
        end

        it "should process target directories with the SYSTEM directory last" do
          tf = Tempfile.new('unittest')
          tf.puts("AUTO_DECLARE_TARGETS")
          tf.close
          FileUtils.mkdir_p(File.join(@config_targets, 'ABC'))
          FileUtils.mkdir_p(File.join(@config_targets, 'SYSTEM'))
          FileUtils.mkdir_p(File.join(@config_targets, 'XYZ'))
          System.instance.process_file(tf.path)
          # Since Ruby 1.9+ uses ordered Hashes we can ask for the keys and
          # SYSTEM should be last
          System.instance.targets.keys.should eql %w(ABC XYZ SYSTEM)
          Dir.rmdir(File.join(@config_targets, 'ABC'))
          Dir.rmdir(File.join(@config_targets, 'SYSTEM'))
          Dir.rmdir(File.join(@config_targets, 'XYZ'))
          tf.unlink
        end
      end

      context "with DECLARE_TARGET" do
        it "should take 1 or 2 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("DECLARE_TARGET")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Not enough parameters for DECLARE_TARGET.")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("DECLARE_TARGET TGT TGT TGT TGT")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for DECLARE_TARGET.")
          tf.unlink
        end

        it "should complain if the target directory doesn't exist" do
          tf = Tempfile.new('unittest')
          tf.puts("DECLARE_TARGET TGT")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Target folder must exist/)
          tf.unlink
        end

        it "should process the target directory" do
          tf = Tempfile.new('unittest')
          tf.puts("DECLARE_TARGET TGT")
          tf.close
          FileUtils.mkdir_p(File.join(@config_targets, 'TGT'))
          System.instance.process_file(tf.path)
          tf.unlink
        end

        it "should process the target directory with substitute name" do
          tf = Tempfile.new('unittest')
          tf.puts("DECLARE_TARGET TGT NEW")
          tf.close
          FileUtils.mkdir_p(File.join(@config_targets, 'TGT'))
          System.instance.process_file(tf.path)
          tf.unlink
        end

        it "should process the target directory with specified target.txt" do
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
        it "should take 2 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("PORT CTS_API")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Not enough parameters for PORT.")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("PORT CTS_API 8888 TRUE")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for PORT.")
          tf.unlink
        end

        it "should complain about unknown ports" do
          tf = Tempfile.new('unittest')
          tf.puts("PORT MYPORT 10")
          tf.close
          capture_io do |stdout|
            System.instance.process_file(tf.path)
            stdout.string.should match /WARN: Unknown port name given: MYPORT/
          end
          tf.unlink
        end

        it "should change known ports" do
          tf = Tempfile.new('unittest')
          tf.puts("PORT CTS_API 8888")
          tf.close
          System.ports['CTS_API'].should eql 7777
          System.instance.process_file(tf.path)
          System.ports['CTS_API'].should eql 8888
          tf.unlink
        end
      end

      context "with PATH" do
        it "should take 2 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("PATH C:/")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Not enough parameters for PATH.")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("PATH MYPATH C:/ TRUE")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for PATH.")
          tf.unlink
        end

        it "should complain about unknown paths" do
          tf = Tempfile.new('unittest')
          tf.puts("PATH MYPATH C:/")
          tf.close
          capture_io do |stdout|
            System.instance.process_file(tf.path)
            stdout.string.should match /WARN: Unknown path name given: MYPATH/
          end
          tf.unlink
        end

        it "should change known paths" do
          tf = Tempfile.new('unittest')
          tf.puts("PATH LOGS C:/mylogs")
          tf.close
          System.paths['LOGS'].should match 'outputs/logs'
          System.instance.process_file(tf.path)
          System.paths['LOGS'].should eql 'C:/mylogs'
          tf.unlink
        end
      end

      context "with DEFAULT_PACKET_LOG_WRITER" do
        it "should take 1 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("DEFAULT_PACKET_LOG_WRITER")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Not enough parameters for DEFAULT_PACKET_LOG_WRITER.")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("DEFAULT_PACKET_LOG_WRITER my_nonexistent_class TRUE")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for DEFAULT_PACKET_LOG_WRITER.")
          tf.unlink
        end

        it "should complain if the class doesn't exist" do
          tf = Tempfile.new('unittest')
          tf.puts("DEFAULT_PACKET_LOG_WRITER my_nonexistent_class")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(/Unable to require my_nonexistent_class/)
          tf.unlink
        end

        it "should set the packet writer" do
          filename = File.join(File.dirname(__FILE__),'..','..','lib','my_writer.rb')
          File.open(filename, 'w') do |file|
            file.puts "class MyWriter"
            file.puts "end"
          end
          tf = Tempfile.new('unittest')
          tf.puts("DEFAULT_PACKET_LOG_WRITER my_writer")
          tf.close
          System.instance.process_file(tf.path)
          System.default_packet_log_writer.should eql MyWriter
          File.delete filename
          tf.unlink
        end
      end

      context "with DEFAULT_PACKET_LOG_READER" do
        it "should take 1 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("DEFAULT_PACKET_LOG_READER")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Not enough parameters for DEFAULT_PACKET_LOG_READER.")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("DEFAULT_PACKET_LOG_READER my_nonexistent_class TRUE")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for DEFAULT_PACKET_LOG_READER.")
          tf.unlink
        end

        it "should complain if the class doesn't exist" do
          tf = Tempfile.new('unittest')
          tf.puts("DEFAULT_PACKET_LOG_READER my_nonexistent_class")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(/Unable to require my_nonexistent_class/)
          tf.unlink
        end

        it "should set the packet reader" do
          filename = File.join(File.dirname(__FILE__),'..','..','lib','my_reader.rb')
          File.open(filename, 'w') do |file|
            file.puts "class MyReader"
            file.puts "end"
          end
          tf = Tempfile.new('unittest')
          tf.puts("DEFAULT_PACKET_LOG_READER my_reader")
          tf.close
          System.instance.process_file(tf.path)
          System.default_packet_log_reader.should eql MyReader
          File.delete filename
          tf.unlink
        end
      end

      context "with DISABLE_DNS" do
        it "should take 0 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("DISABLE_DNS BLAH TRUE")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for DISABLE_DNS.")
          tf.unlink
        end

        it "should disable dns lookups" do
          tf = Tempfile.new('unittest')
          tf.puts("DISABLE_DNS")
          tf.close
          System.use_dns.should be_truthy
          System.instance.process_file(tf.path)
          System.use_dns.should be_falsey
          tf.unlink
        end
      end

      context "with ALLOW_ACCESS" do
        it "should take 1 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("ALLOW_ACCESS")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Not enough parameters for ALLOW_ACCESS.")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("ALLOW_ACCESS localhost true")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for ALLOW_ACCESS.")
          tf.unlink
        end

        it "should complain about bad addresses" do
          tf = Tempfile.new('unittest')
          tf.puts("ALLOW_ACCESS 123456789")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Problem with ALLOW_ACCESS due to badly formatted address 123456789")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("ALLOW_ACCESS hopefully_this_is_not_a_valid_machine_name_XYZ")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Problem with ALLOW_ACCESS due to getaddrinfo: No such host is known.")
          tf.unlink
        end

        it "should allow ALL" do
          tf = Tempfile.new('unittest')
          tf.puts("ALLOW_ACCESS ALL")
          tf.close
          System.instance.process_file(tf.path)
          System.acl.should be_nil
          tf.unlink
        end

        it "should store host by name" do
          tf = Tempfile.new('unittest')
          tf.puts("ALLOW_ACCESS localhost")
          tf.close
          System.instance.process_file(tf.path)
          System.acl.allow_addr?(["AF_INET",0,"localhost","127.0.0.1"]).should be_truthy
          tf.unlink
        end

        it "should store host by IP address" do
          addr = IPSocket.getaddress("www.google.com")
          tf = Tempfile.new('unittest')
          tf.puts("ALLOW_ACCESS #{addr}")
          tf.close
          System.instance.process_file(tf.path)
          System.acl.allow_addr?(["AF_INET",0,"www.google.com",addr]).should be_truthy
          tf.unlink
        end
      end

      context "with STALENESS_SECONDS" do
        it "should take 1 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("STALENESS_SECONDS")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Not enough parameters for STALENESS_SECONDS.")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("STALENESS_SECONDS 1 2")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for STALENESS_SECONDS.")
          tf.unlink
        end

        it "should set the number of seconds required to be stale" do
          tf = Tempfile.new('unittest')
          tf.puts("STALENESS_SECONDS 3")
          tf.close
          System.staleness_seconds.should eql 30
          System.instance.process_file(tf.path)
          System.staleness_seconds.should eql 3
          tf.unlink
        end
      end

      context "with CMD_TLM_VERSION" do
        it "should take 1 parameters" do
          tf = Tempfile.new('unittest')
          tf.puts("CMD_TLM_VERSION")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Not enough parameters for CMD_TLM_VERSION.")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts("CMD_TLM_VERSION 1 2")
          tf.close
          expect { System.instance.process_file(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for CMD_TLM_VERSION.")
          tf.unlink
        end

        it "should set the command and telemetry version" do
          tf = Tempfile.new('unittest')
          tf.puts("CMD_TLM_VERSION 2.1")
          tf.close
          System.cmd_tlm_version.should be_nil
          System.instance.process_file(tf.path)
          System.cmd_tlm_version.should eql "2.1"
          tf.unlink
        end
      end
    end

    describe "Cosmos.write_exception_file" do
      it "should write a file with the exception" do
        filename = Cosmos.write_exception_file(RuntimeError.new("HELP!"))
        File.exist?(filename).should be_truthy
        File.delete(filename)
      end

      it "should write a file without a defined LOGS directory" do
        File.open(@config_file,'w') {|file| file.puts "PATH LOGS C:/this/is/not/a/real/path" }
        # Reset the instance variable so it will read the new config file
        System.instance_eval('@instance = nil')
        filename = Cosmos.write_exception_file(RuntimeError.new("HELP!"))
        File.exist?(filename).should be_truthy
        File.delete(filename)
      end
    end
  end
end

