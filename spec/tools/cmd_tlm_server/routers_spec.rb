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
    describe "start" do
      it "connects each router" do
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

          expect(stdout.string).to match("Creating thread for router MY_ROUTER")
          routers.stop
        end
        tf.unlink
        sleep(0.2)
      end
    end

    describe "stop" do
      it "disconnects each router" do
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
          expect(routers.state("MY_ROUTER")).to eql "ATTEMPTING"
          expect(routers.state("MY_ROUTER")).to eql "CONNECTED"
          routers.stop
          sleep 0.1
          expect(routers.state("MY_ROUTER")).to eql "DISCONNECTED"

          expect(stdout.string).to match("Disconnected from router MY_ROUTER")
        end
        tf.unlink
        sleep(0.2)
      end
    end

    describe "add_preidentified" do
      it "adds a preidentified router to all interfaces" do
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE DEST1 tcpip_client_interface.rb localhost 8888 8888 5 5 burst'
        tf.puts 'INTERFACE DEST2 tcpip_client_interface.rb localhost 8888 8888 5 5 burst'
        tf.close
        config = CmdTlmServerConfig.new(tf.path)
        expect(config.interfaces.keys).to eql %w(DEST1 DEST2)
        expect(config.interfaces['DEST1'].routers).to be_empty
        expect(config.interfaces['DEST2'].routers).to be_empty

        routers = Routers.new(config)
        expect(routers.all.keys).to be_empty
        routers.add_preidentified("PRE", 9999)
        expect(routers.all.keys).to eql %w(PRE)

        expect(config.interfaces['DEST1'].routers[0].name).to eql "PRE"
        expect(config.interfaces['DEST2'].routers[0].name).to eql "PRE"
        tf.unlink
      end
    end

    describe "recreate" do
      it "complains about unknown routers" do
        tf = Tempfile.new('unittest')
        tf.puts 'ROUTER MY_ROUTER interface.rb'
        tf.close
        routers = Routers.new(CmdTlmServerConfig.new(tf.path))
        expect { routers.recreate("BLAH") }.to raise_error("Unknown router: BLAH")
        tf.unlink
      end
    end

    describe "connect" do
      it "complains about unknown routers" do
        tf = Tempfile.new('unittest')
        tf.puts 'ROUTER MY_ROUTER interface.rb'
        tf.close
        routers = Routers.new(CmdTlmServerConfig.new(tf.path))
        expect { routers.connect("TEST") }.to raise_error("Unknown router: TEST")
        tf.unlink
      end

      it "connects a router" do
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE DEST1 tcpip_client_interface.rb localhost 8888 8888 5 5 burst'
        tf.puts 'INTERFACE DEST2 tcpip_client_interface.rb localhost 8888 8888 5 5 burst'
        tf.puts 'ROUTER MY_ROUTER tcpip_client_interface.rb localhost 8888 8888 5 5 burst'
        tf.puts 'ROUTE DEST1'
        tf.puts 'ROUTE DEST2'
        tf.close
        capture_io do |stdout|
          server = TCPServer.new('127.0.0.1', 8888)
          def server.graceful_kill
          end
          clients = []
          pipe_reader, pipe_writer = IO.pipe
          server_thread = Thread.new do
            loop do
              clients << server.accept
              begin
                clients << server.accept_nonblock
              rescue Errno::EAGAIN, Errno::ECONNABORTED, Errno::EINTR, Errno::EWOULDBLOCK
                read_ready, _ = IO.select([server, pipe_reader])
                if read_ready.include?(pipe_reader)
                  break
                else
                  retry
                end
              end
            end
          end


          config = CmdTlmServerConfig.new(tf.path)
          routers = Routers.new(config)
          expect(routers.all["MY_ROUTER"].interfaces[0].name).to eql "DEST1"
          expect(routers.all["MY_ROUTER"].interfaces[1].name).to eql "DEST2"
          expect(config.interfaces['DEST1'].routers[0].name).to eql "MY_ROUTER"
          expect(config.interfaces['DEST2'].routers[0].name).to eql "MY_ROUTER"
          routers.connect("MY_ROUTER")
          sleep 0.1
          expect(stdout.string).to match("Connecting to MY_ROUTER")
          routers.disconnect("MY_ROUTER")
          routers.connect("MY_ROUTER",'localhost',8888,8888,6,6,'length')
          sleep 0.1
          expect(stdout.string).to match("Disconnected from router MY_ROUTER")
          expect(stdout.string).to match("Connecting to MY_ROUTER")
          expect(routers.all["MY_ROUTER"].interfaces[0].name).to eql "DEST1"
          expect(routers.all["MY_ROUTER"].interfaces[1].name).to eql "DEST2"
          expect(config.interfaces['DEST1'].routers[0].name).to eql "MY_ROUTER"
          expect(config.interfaces['DEST2'].routers[0].name).to eql "MY_ROUTER"
          routers.disconnect("MY_ROUTER")
          routers.stop

          pipe_writer.write('.')
          Cosmos.kill_thread(server, server_thread)
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
      it "lists all the router names" do
        tf = Tempfile.new('unittest')
        tf.puts 'ROUTER ROUTER1 interface.rb'
        tf.puts 'ROUTER ROUTER2 interface.rb'
        tf.puts 'ROUTER ROUTER3 interface.rb'
        tf.close
        routers = Routers.new(CmdTlmServerConfig.new(tf.path))
        expect(routers.names).to eql %w(ROUTER1 ROUTER2 ROUTER3)
        tf.unlink
      end
    end

    describe "clear_counters" do
      it "clears all router counters" do
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
          expect(router.bytes_written).to eql 0
          expect(router.bytes_read).to eql 0
          expect(router.write_count).to eql 0
          expect(router.read_count).to eql 0
        end
        tf.unlink
      end
    end
  end
end

