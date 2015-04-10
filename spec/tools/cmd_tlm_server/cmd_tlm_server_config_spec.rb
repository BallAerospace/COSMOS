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
require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server'
require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server_config'
require 'tempfile'
load 'cosmos.rb' # Ensure COSMOS::USERPATH/lib is set

module Cosmos

  describe CmdTlmServerConfig do
    before(:all) do
      @interface_filename = File.join(Cosmos::USERPATH,'lib','cts_config_test_interface.rb')
      File.open(@interface_filename,'w') do |file|
        file.puts "require 'cosmos'"
        file.puts "require 'cosmos/interfaces/interface'"
        file.puts "module Cosmos"
        file.puts "  class CtsConfigTestInterface < Interface"
        file.puts "    def initialize(test = true)"
        file.puts "      super()"
        file.puts "    end"
        file.puts "  end"
        file.puts "end"
      end

      @keywords = %w(TITLE PACKET_LOG_WRITER AUTO_INTERFACE_TARGETS INTERFACE_TARGET INTERFACE ROUTER)
      @interface_keywords = %w(DONT_CONNECT DONT_RECONNECT RECONNECT_DELAY DISABLE_DISCONNECT LOG DONT_LOG TARGET)
    end

    after(:all) do
      clean_config()
      File.delete @interface_filename
    end

    describe "process_file" do
      it "complains if there is an unknown keyword" do
        tf = Tempfile.new('unittest')
        tf.puts "UNKNOWN"
        tf.close
        expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "Unknown keyword: UNKNOWN")
        tf.unlink
      end

      it "complains if there are not enough parameters" do
        @keywords.each do |keyword|
          next if %w(AUTO_INTERFACE_TARGETS).include? keyword
          tf = Tempfile.new('unittest')
          tf.puts keyword
          tf.close
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "Not enough parameters for #{keyword}.")
          tf.unlink
        end

        @interface_keywords.each do |keyword|
          next if %w(DONT_CONNECT DONT_RECONNECT DISABLE_DISCONNECT DONT_LOG).include? keyword
          tf = Tempfile.new('unittest')
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.puts keyword
          tf.close
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "Not enough parameters for #{keyword}.")
          tf.unlink
        end
      end

      context "with TITLE" do
        it "complains about too many parameters" do
          tf = Tempfile.new('unittest')
          tf.puts 'TITLE HI THERE'
          tf.close
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for TITLE.")
          tf.unlink
        end

        it "sets the title" do
          tf = Tempfile.new('unittest')
          tf.puts 'TITLE TEST'
          tf.close
          config = CmdTlmServerConfig.new(tf.path)
          expect(config.title).to eql "TEST"
          tf.unlink
        end
      end

      context "with PACKET_LOG_WRITER" do
        it "sets the packet log writer" do
          tf = Tempfile.new('unittest')
          tf.puts 'PACKET_LOG_WRITER MY_WRITER packet_log_writer.rb'
          tf.close
          config =CmdTlmServerConfig.new(tf.path)
          expect(config.packet_log_writer_pairs.keys).to eql ["DEFAULT","MY_WRITER"]
          tf.unlink
        end

        it "sets the packet log writer with parameters" do
          tf = Tempfile.new('unittest')
          tf.puts 'PACKET_LOG_WRITER MY_WRITER packet_log_writer.rb test_log_name false 3 1000 C:\log false'
          tf.close
          config = CmdTlmServerConfig.new(tf.path)
          expect(config.packet_log_writer_pairs.keys).to eql ["DEFAULT","MY_WRITER"]
          expect(config.packet_log_writer_pairs["DEFAULT"].cmd_log_writer.logging_enabled).to be true
          expect(config.packet_log_writer_pairs["MY_WRITER"].cmd_log_writer.logging_enabled).to be false
          tf.unlink
          config.packet_log_writer_pairs.each do |name, plwp|
            plwp.cmd_log_writer.shutdown
            plwp.tlm_log_writer.shutdown
          end
          sleep(0.2)
        end
      end

      context "with AUTO_INTERFACE_TARGETS" do
        it "complains about too many parameters" do
          tf = Tempfile.new('unittest')
          tf.puts 'AUTO_INTERFACE_TARGETS BLAH'
          tf.close
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for AUTO_INTERFACE_TARGETS.")
          tf.unlink
        end

        it "automatically processes interfaces" do
          # Stub out the CmdTlmServer
          allow(CmdTlmServer).to receive_message_chain(:instance, :subscribe_limits_events)

          tf = Tempfile.new('unittest')
          tf.puts 'AUTO_INTERFACE_TARGETS'
          tf.close
          config = CmdTlmServerConfig.new(tf.path)
          expect(config.interfaces.keys).to eql %w(INST_INT COSMOSINT)
          tf.unlink
        end
      end

      context "with INTERFACE_TARGET" do
        it "complains about too many parameters" do
          tf = Tempfile.new('unittest')
          tf.puts 'INTERFACE_TARGET BLAH config.txt MORE'
          tf.close
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for INTERFACE_TARGET.")
          tf.unlink
        end

        it "complains about unknown targets" do
          tf = Tempfile.new('unittest')
          tf.puts 'INTERFACE_TARGET BLAH'
          tf.close
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "Unknown target: BLAH")
          tf.unlink
        end

        it "complains about unknown target files" do
          tf = Tempfile.new('unittest')
          tf.puts 'INTERFACE_TARGET TEST'
          tf.close
          System.targets["TEST"] = Target.new("TEST")
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, /TEST\/cmd_tlm_server.txt does not exist/)
          tf.unlink
        end

        it "processes an interface" do
          tf = Tempfile.new('unittest')
          tf.puts 'INTERFACE_TARGET INST'
          tf.close
          config = CmdTlmServerConfig.new(tf.path)
          expect(config.interfaces.keys).to eql %w(INST_INT)
          tf.unlink
        end
      end

      context "with DONT_CONNECT" do
        it "complains about too many parameters" do
          tf = Tempfile.new('unittest')
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.puts 'DONT_CONNECT TRUE'
          tf.close
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for DONT_CONNECT.")
          tf.unlink
        end

        it "sets the interface to not connect on startup" do
          tf = Tempfile.new('unittest')
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.puts 'DONT_CONNECT'
          tf.close
          config = CmdTlmServerConfig.new(tf.path)
          expect(config.interfaces['CTSCONFIGTESTINTERFACE'].connect_on_startup).to be false
          tf.unlink
        end
      end

      context "with DONT_RECONNECT" do
        it "complains about too many parameters" do
          tf = Tempfile.new('unittest')
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.puts 'DONT_RECONNECT TRUE'
          tf.close
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for DONT_RECONNECT.")
          tf.unlink
        end

        it "sets the interface to not auto reconnect" do
          tf = Tempfile.new('unittest')
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.puts 'DONT_RECONNECT'
          tf.close
          config = CmdTlmServerConfig.new(tf.path)
          expect(config.interfaces['CTSCONFIGTESTINTERFACE'].auto_reconnect).to be false
          tf.unlink
        end
      end

      context "with RECONNECT_DELAY" do
        it "complains about too many parameters" do
          tf = Tempfile.new('unittest')
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.puts 'RECONNECT_DELAY 5.0 TRUE'
          tf.close
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for RECONNECT_DELAY.")
          tf.unlink
        end

        it "sets the delay between reconnect tries" do
          tf = Tempfile.new('unittest')
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.puts 'RECONNECT_DELAY 5.0'
          tf.close
          config = CmdTlmServerConfig.new(tf.path)
          expect(config.interfaces['CTSCONFIGTESTINTERFACE'].reconnect_delay).to eql 5.0
          tf.unlink
        end
      end

      context "with DISABLE_DISCONNECT" do
        it "complains about too many parameters" do
          tf = Tempfile.new('unittest')
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.puts 'DISABLE_DISCONNECT TRUE'
          tf.close
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for DISABLE_DISCONNECT.")
          tf.unlink
        end

        it "sets the interface to not allow disconnects" do
          tf = Tempfile.new('unittest')
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.puts 'DISABLE_DISCONNECT'
          tf.close
          config = CmdTlmServerConfig.new(tf.path)
          expect(config.interfaces['CTSCONFIGTESTINTERFACE'].disable_disconnect).to be true
          tf.unlink
        end
      end

      context "with OPTION" do
        it "complains about too few parameters" do
          tf = Tempfile.new('unittest')
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.puts 'OPTION TRUE'
          tf.close
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "Not enough parameters for OPTION.")
          tf.unlink
        end

        it "sets the interface to listen on a specific address" do
          tf = Tempfile.new('unittest')
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.puts 'OPTION LISTEN_ADDRESS 127.0.0.1'
          tf.close
          config = CmdTlmServerConfig.new(tf.path)
          expect(config.interfaces['CTSCONFIGTESTINTERFACE'].options['LISTEN_ADDRESS']).to eql(['127.0.0.1'])
          tf.unlink
        end
      end

      context "with LOG" do
        it "complains about too many parameters" do
          tf = Tempfile.new('unittest')
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.puts 'LOG PacketLogWriter TRUE'
          tf.close
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for LOG.")
          tf.unlink
        end

        it "complains about unknown log writers" do
          tf = Tempfile.new('unittest')
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.puts 'LOG MyLogWriter'
          tf.close
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "Unknown packet log writer: MYLOGWRITER")
          tf.unlink
        end

        it "adds a packet log writer to the interface" do
          tf = Tempfile.new('unittest')
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.puts 'LOG DEFAULT'
          tf.close
          config = CmdTlmServerConfig.new(tf.path)
          expect(config.interfaces['CTSCONFIGTESTINTERFACE'].packet_log_writer_pairs.length).to eql 1
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'PACKET_LOG_WRITER MY_WRITER packet_log_writer.rb'
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.puts 'LOG DEFAULT'
          tf.puts 'LOG MY_WRITER'
          tf.close
          config = CmdTlmServerConfig.new(tf.path)
          expect(config.interfaces['CTSCONFIGTESTINTERFACE'].packet_log_writer_pairs.length).to eql 2
          tf.unlink
        end
      end

      context "with DONT_LOG" do
        it "complains about too many parameters" do
          tf = Tempfile.new('unittest')
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.puts 'DONT_LOG TRUE'
          tf.close
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for DONT_LOG.")
          tf.unlink
        end

        it "removes loggers from the interface" do
          tf = Tempfile.new('unittest')
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.puts 'DONT_LOG'
          tf.close
          config = CmdTlmServerConfig.new(tf.path)
          expect(config.interfaces['CTSCONFIGTESTINTERFACE'].packet_log_writer_pairs.length).to eql 0
          tf.unlink
        end
      end

      context "with TARGET" do
        it "complains about too many parameters" do
          tf = Tempfile.new('unittest')
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.puts 'TARGET TEST TRUE'
          tf.close
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for TARGET.")
          tf.unlink
        end

        it "complains about unknown targets" do
          tf = Tempfile.new('unittest')
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.puts 'TARGET BLAH'
          tf.close
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "Unknown target BLAH mapped to interface CTSCONFIGTESTINTERFACE")
          tf.unlink
        end
      end

      context "with two interfaces with the same name" do
        it "complains about duplicate interface names" do
          tf = Tempfile.new('unittest')
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.close
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "Interface 'CTSCONFIGTESTINTERFACE' defined twice")
          tf.unlink
        end
      end

      context "with two routers with the same name" do
        it "complains about duplicate router names" do
          tf = Tempfile.new('unittest')
          tf.puts "ROUTER MY_ROUTER1 cts_config_test_interface.rb"
          tf.puts "ROUTER MY_ROUTER1 cts_config_test_interface.rb"
          tf.close
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "Router 'MY_ROUTER1' defined twice")
          tf.unlink
        end
      end

      context "with ROUTER" do
        it "creates a new router" do
          tf = Tempfile.new('unittest')
          tf.puts 'ROUTER MY_ROUTER1 cts_config_test_interface.rb'
          tf.puts 'ROUTER MY_ROUTER2 cts_config_test_interface.rb false'
          tf.close
          config = CmdTlmServerConfig.new(tf.path)
          expect(config.routers.keys).to eql %w(MY_ROUTER1 MY_ROUTER2)
          tf.unlink
        end
      end

      context "with ROUTE" do
        it "complains about too many parameters" do
          tf = Tempfile.new('unittest')
          tf.puts 'ROUTER ROUTER cts_config_test_interface.rb'
          tf.puts 'ROUTE interface more'
          tf.close
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "Too many parameters for ROUTE.")
          tf.unlink
        end

        it "complains if a router hasn't been defined" do
          tf = Tempfile.new('unittest')
          tf.puts 'ROUTE interface more'
          tf.close
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "No current router for ROUTE")
          tf.unlink
        end

        it "complains if the interface is undefined" do
          tf = Tempfile.new('unittest')
          tf.puts 'ROUTER ROUTER cts_config_test_interface.rb'
          tf.puts 'ROUTE CTSCONFIGTESTINTERFACE'
          tf.close
          expect { CmdTlmServerConfig.new(tf.path) }.to raise_error(ConfigParser::Error, "Unknown interface CTSCONFIGTESTINTERFACE mapped to router ROUTER")
          tf.unlink
        end

        it "creates the route" do
          tf = Tempfile.new('unittest')
          tf.puts "INTERFACE CtsConfigTestInterface cts_config_test_interface.rb"
          tf.puts 'ROUTER ROUTER cts_config_test_interface.rb'
          tf.puts 'ROUTE CTSCONFIGTESTINTERFACE'
          tf.close
          config = CmdTlmServerConfig.new(tf.path)
          expect(config.routers['ROUTER'].interfaces[0]).to be_a CtsConfigTestInterface
          tf.unlink
        end
      end

      context "with BACKGROUND_TASK" do
        it "creates a background task" do
          tf = Tempfile.new('unittest')
          tf.puts 'BACKGROUND_TASK cts_config_test_interface.rb'
          tf.puts 'BACKGROUND_TASK cts_config_test_interface.rb false'
          tf.close
          config = CmdTlmServerConfig.new(tf.path)
          expect(config.background_tasks.length).to eql 2
          expect(config.background_tasks[0]).to be_a CtsConfigTestInterface
          expect(config.background_tasks[1]).to be_a CtsConfigTestInterface
          tf.unlink
        end
      end

    end
  end
end
