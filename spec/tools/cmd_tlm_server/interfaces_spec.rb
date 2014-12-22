# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'tempfile'
require 'cosmos'
require 'cosmos/tools/cmd_tlm_server/interfaces'
require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server_config'

module Cosmos

  describe Interfaces do
    after(:all) do
      clean_config()
    end

    describe "map_all_targets" do
      it "should complain about an unknown interface" do
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE MY_INT interface.rb'
        tf.close
        interfaces = Interfaces.new(CmdTlmServerConfig.new(tf.path))
        expect { interfaces.map_all_targets("BLAH") }.to raise_error("Unknown interface: BLAH")
        tf.unlink
      end

      it "should map all targets to the interface" do
        System.targets.each do |name, target|
          target.interface = nil
          target.interface.should be_nil
        end
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE MY_INT interface.rb'
        tf.close
        interfaces = Interfaces.new(CmdTlmServerConfig.new(tf.path))
        interfaces.map_all_targets("MY_INT")
        System.targets.each do |name, target|
          target.interface.name.should eql 'MY_INT'
        end
        tf.unlink
      end
    end

    describe "map_target" do
      it "should complain about an unknowwn interface" do
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE MY_INT interface.rb'
        tf.close
        interfaces = Interfaces.new(CmdTlmServerConfig.new(tf.path))
        expect { interfaces.map_target("COSMOS","BLAH") }.to raise_error("Unknown interface: BLAH")
        tf.unlink
      end

      it "should complain about an unknown target" do
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE MY_INT interface.rb'
        tf.close
        interfaces = Interfaces.new(CmdTlmServerConfig.new(tf.path))
        expect { interfaces.map_target("BLAH","MY_INT") }.to raise_error("Unknown target: BLAH")
        tf.unlink
      end


      it "should map a target to the interface" do
        System.targets.each do |name, target|
          target.interface = nil
          target.interface.should be_nil
        end
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE MY_INT interface.rb'
        tf.close
        interfaces = Interfaces.new(CmdTlmServerConfig.new(tf.path))
        interfaces.map_target("COSMOS","MY_INT")
        System.targets["COSMOS"].interface.name.should eql "MY_INT"
        tf.unlink
      end
    end

    describe "start" do
      it "should connect each interface" do
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE MY_INT interface.rb'
        tf.close
        capture_io do |stdout|
          interfaces = Interfaces.new(CmdTlmServerConfig.new(tf.path))
          interfaces.all['MY_INT'].connect_on_startup = false

          allow_any_instance_of(Interface).to receive(:connected?)
          allow_any_instance_of(Interface).to receive(:connect)
          allow_any_instance_of(Interface).to receive(:disconnect)
          allow_any_instance_of(Interface).to receive(:read)

          interfaces.all['MY_INT'].connect_on_startup = true
          interfaces.start

          stdout.string.should match "Creating thread for interface MY_INT"

          interfaces.stop
          sleep 0.1
        end
        tf.unlink
      end
    end

    describe "stop" do
      it "should disconnect each interface" do
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE MY_INT interface.rb'
        tf.close
        capture_io do |stdout|
          interfaces = Interfaces.new(CmdTlmServerConfig.new(tf.path))

          allow_any_instance_of(Interface).to receive(:connected?).and_return(false, false, true, false)
          allow_any_instance_of(Interface).to receive(:connect)
          allow_any_instance_of(Interface).to receive(:disconnect)
          allow_any_instance_of(Interface).to receive(:read)

          interfaces.all['MY_INT'].connect_on_startup = true
          interfaces.start
          sleep 0.5
          interfaces.state("MY_INT").should eql "ATTEMPTING"
          sleep 0.1
          interfaces.state("MY_INT").should eql "CONNECTED"
          sleep 0.1
          interfaces.stop
          sleep 0.5
          interfaces.state("MY_INT").should eql "DISCONNECTED"

          stdout.string.should match "Disconnected from interface MY_INT"

          sleep 0.1
        end
        tf.unlink
      end
    end

    describe "connect" do
      it "should complain about unknown interfaces" do
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE MY_INT interface.rb'
        tf.close
        interfaces = Interfaces.new(CmdTlmServerConfig.new(tf.path))
        expect { interfaces.connect("TEST") }.to raise_error("Unknown interface: TEST")
        tf.unlink
      end

      it "should connect a interface" do
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE DEST1 tcpip_client_interface.rb localhost 8888 8888 5 5 burst'
        tf.puts 'INTERFACE DEST2 tcpip_client_interface.rb localhost 8888 8888 5 5 burst'
        tf.puts 'ROUTER MY_ROUTER tcpip_client_interface.rb localhost 8888 8888 5 5 burst'
        tf.puts 'ROUTE DEST1'
        tf.puts 'ROUTE DEST2'
        tf.close
        capture_io do |stdout|
          server = TCPServer.new(8888)
          Thread.new do
            client = server.accept
            client.close
          end

          config = CmdTlmServerConfig.new(tf.path)
          interfaces = Interfaces.new(config)
          config.interfaces['DEST1'].routers[0].name.should eql "MY_ROUTER"
          config.interfaces['DEST2'].routers[0].name.should eql "MY_ROUTER"
          interfaces.connect("DEST1")
          sleep 0.1
          stdout.string.should match "Connecting to DEST1"
          interfaces.disconnect("DEST1")
          interfaces.connect("DEST1",'localhost',9888,9888,6,6,'length')
          sleep 0.1
          config.interfaces['DEST1'].routers[0].name.should eql "MY_ROUTER"
          config.interfaces['DEST2'].routers[0].name.should eql "MY_ROUTER"
          stdout.string.should match "Disconnected from interface DEST1"
          stdout.string.should match "Connecting to DEST1"
          interfaces.disconnect("DEST1")
        end
        tf.unlink
      end
    end

    describe "names" do
      it "should list all the interface names" do
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE INTERFACE1 interface.rb'
        tf.puts 'INTERFACE INTERFACE2 interface.rb'
        tf.puts 'INTERFACE INTERFACE3 interface.rb'
        tf.close
        interfaces = Interfaces.new(CmdTlmServerConfig.new(tf.path))
        interfaces.names.should eql %w(INTERFACE1 INTERFACE2 INTERFACE3)
        tf.unlink
      end
    end

    describe "clear_counters" do
      it "should clear all interface counters" do
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE INTERFACE1 interface.rb'
        tf.puts 'INTERFACE INTERFACE2 interface.rb'
        tf.puts 'INTERFACE INTERFACE3 interface.rb'
        tf.close
        interfaces = Interfaces.new(CmdTlmServerConfig.new(tf.path))
        interfaces.all.each do |name, interface|
          interface.bytes_written = 100
          interface.bytes_read = 200
          interface.write_count = 10
          interface.read_count = 20
        end
        interfaces.clear_counters
        interfaces.all.each do |name, interface|
          interface.bytes_written.should eql 0
          interface.bytes_read.should eql 0
          interface.write_count.should eql 0
          interface.read_count.should eql 0
        end
        tf.unlink
      end
    end
  end
end

