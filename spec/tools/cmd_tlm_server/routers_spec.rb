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
require 'cosmos/tools/cmd_tlm_server/routers'
require 'tempfile'

module Cosmos

  describe Routers do
    after(:all) do
      clean_config()
    end

    describe "start" do
      it "should connect each router" do
        tf = Tempfile.new('unittest')
        tf.puts 'ROUTER MY_ROUTER interface.rb'
        tf.close
        capture_io do |stdout|
          routers = Routers.new(CmdTlmServerConfig.new(tf.path))
          routers.all['MY_ROUTER'].connect_on_startup = false

          allow_any_instance_of(Interface).to receive(:connected?)
          allow_any_instance_of(Interface).to receive(:connect)
          allow_any_instance_of(Interface).to receive(:disconnect)
          allow_any_instance_of(Interface).to receive(:read)

          routers.all['MY_ROUTER'].connect_on_startup = true
          routers.start

          stdout.string.should match "Creating thread for router MY_ROUTER"
          routers.stop
        end
        tf.unlink
        sleep(0.2)
      end
    end

    describe "stop" do
      it "should disconnect each router" do
        tf = Tempfile.new('unittest')
        tf.puts 'ROUTER MY_ROUTER interface.rb'
        tf.close
        capture_io do |stdout|
          routers = Routers.new(CmdTlmServerConfig.new(tf.path))

          allow_any_instance_of(Interface).to receive(:connected?).and_return(false, false, true, false)
          allow_any_instance_of(Interface).to receive(:connect)
          allow_any_instance_of(Interface).to receive(:disconnect)
          allow_any_instance_of(Interface).to receive(:read)

          routers.all['MY_ROUTER'].connect_on_startup = true
          routers.start
          sleep 0.1
          routers.state("MY_ROUTER").should eql "ATTEMPTING"
          routers.state("MY_ROUTER").should eql "CONNECTED"
          routers.stop
          sleep 0.1
          routers.state("MY_ROUTER").should eql "DISCONNECTED"

          stdout.string.should match "Disconnected from router MY_ROUTER"
        end
        tf.unlink
        sleep(0.2)
      end
    end

    describe "add_preidentified" do
      it "should add a preidentified router to all interfaces" do
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE DEST1 tcpip_client_interface.rb localhost 8888 8888 5 5 burst'
        tf.puts 'INTERFACE DEST2 tcpip_client_interface.rb localhost 8888 8888 5 5 burst'
        tf.close
        config = CmdTlmServerConfig.new(tf.path)
        config.interfaces.keys.should eql %w(DEST1 DEST2)
        config.interfaces['DEST1'].routers.should be_empty
        config.interfaces['DEST2'].routers.should be_empty

        routers = Routers.new(config)
        routers.all.keys.should be_empty
        routers.add_preidentified("PRE", 9999)
        routers.all.keys.should eql %w(PRE)

        config.interfaces['DEST1'].routers[0].name.should eql "PRE"
        config.interfaces['DEST2'].routers[0].name.should eql "PRE"
        tf.unlink
      end
    end

    describe "recreate" do
      it "should complain about unknown routers" do
        tf = Tempfile.new('unittest')
        tf.puts 'ROUTER MY_ROUTER interface.rb'
        tf.close
        routers = Routers.new(CmdTlmServerConfig.new(tf.path))
        expect { routers.recreate("BLAH") }.to raise_error("Unknown router: BLAH")
        tf.unlink
      end
    end

    describe "connect" do
      it "should complain about unknown routers" do
        tf = Tempfile.new('unittest')
        tf.puts 'ROUTER MY_ROUTER interface.rb'
        tf.close
        routers = Routers.new(CmdTlmServerConfig.new(tf.path))
        expect { routers.connect("TEST") }.to raise_error("Unknown router: TEST")
        tf.unlink
      end

      it "should connect a router" do
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE DEST1 tcpip_client_interface.rb localhost 8888 8888 5 5 burst'
        tf.puts 'INTERFACE DEST2 tcpip_client_interface.rb localhost 8888 8888 5 5 burst'
        tf.puts 'ROUTER MY_ROUTER tcpip_client_interface.rb localhost 8888 8888 5 5 burst'
        tf.puts 'ROUTE DEST1'
        tf.puts 'ROUTE DEST2'
        tf.close
        capture_io do |stdout|
          server = TCPServer.new('127.0.0.1', 8888)
          clients = []
          server_thread = Thread.new do
            loop do
              clients << server.accept
            end
          end

          config = CmdTlmServerConfig.new(tf.path)
          routers = Routers.new(config)
          routers.all["MY_ROUTER"].interfaces[0].name.should eql "DEST1"
          routers.all["MY_ROUTER"].interfaces[1].name.should eql "DEST2"
          config.interfaces['DEST1'].routers[0].name.should eql "MY_ROUTER"
          config.interfaces['DEST2'].routers[0].name.should eql "MY_ROUTER"
          routers.connect("MY_ROUTER")
          sleep 0.1
          stdout.string.should match "Connecting to MY_ROUTER"
          routers.disconnect("MY_ROUTER")
          routers.connect("MY_ROUTER",'localhost',8888,8888,6,6,'length')
          sleep 0.1
          stdout.string.should match "Disconnected from router MY_ROUTER"
          stdout.string.should match "Connecting to MY_ROUTER"
          routers.all["MY_ROUTER"].interfaces[0].name.should eql "DEST1"
          routers.all["MY_ROUTER"].interfaces[1].name.should eql "DEST2"
          config.interfaces['DEST1'].routers[0].name.should eql "MY_ROUTER"
          config.interfaces['DEST2'].routers[0].name.should eql "MY_ROUTER"
          routers.disconnect("MY_ROUTER")
          routers.stop

          server_thread.kill
          server.close
          clients.each do |c|
            c.close
          end
        end
        tf.unlink
        sleep(0.2)
      end
    end

    describe "names" do
      it "should list all the router names" do
        tf = Tempfile.new('unittest')
        tf.puts 'ROUTER ROUTER1 interface.rb'
        tf.puts 'ROUTER ROUTER2 interface.rb'
        tf.puts 'ROUTER ROUTER3 interface.rb'
        tf.close
        routers = Routers.new(CmdTlmServerConfig.new(tf.path))
        routers.names.should eql %w(ROUTER1 ROUTER2 ROUTER3)
        tf.unlink
      end
    end

    describe "clear_counters" do
      it "should clear all router counters" do
        tf = Tempfile.new('unittest')
        tf.puts 'ROUTER ROUTER1 interface.rb'
        tf.puts 'ROUTER ROUTER2 interface.rb'
        tf.puts 'ROUTER ROUTER3 interface.rb'
        tf.close
        routers = Routers.new(CmdTlmServerConfig.new(tf.path))
        routers.all.each do |name, router|
          router.bytes_written = 100
          router.bytes_read = 200
          router.write_count = 10
          router.read_count = 20
        end
        routers.clear_counters
        routers.all.each do |name, router|
          router.bytes_written.should eql 0
          router.bytes_read.should eql 0
          router.write_count.should eql 0
          router.read_count.should eql 0
        end
        tf.unlink
      end
    end
  end
end

