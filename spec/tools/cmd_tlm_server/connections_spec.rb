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
require 'cosmos/tools/cmd_tlm_server/connections'
require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server_config'
require 'tempfile'

module Cosmos

  describe Connections do
    after(:all) do
      clean_config()
    end

    describe "initialize" do
      it "should only allow :ROUTERS or :INTERFACES" do
        tf = Tempfile.new('unittest')
        tf.close
        expect { Connections.new(:BLAH, CmdTlmServerConfig.new(tf.path)) }.to raise_error("Unknown type: BLAH. Must be :INTERFACES or :ROUTERS.")
        tf.unlink
      end
    end

    describe "start" do
      it "should call connect for each connection" do
        tf = Tempfile.new('unittest')
        tf.puts 'ROUTER MY_ROUTER interface.rb'
        tf.close
        routers = Connections.new(:ROUTERS, CmdTlmServerConfig.new(tf.path))
        expect { routers.start }.to raise_error("Connections start_thread method not implemented")
        tf.unlink
      end
    end

    describe "stop" do
      it "should call disconnect for each connection" do
        allow_any_instance_of(Interface).to receive(:disconnect)
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE MY_INT interface.rb'
        tf.close
        interfaces = Connections.new(:INTERFACES, CmdTlmServerConfig.new(tf.path))
        expect { interfaces.stop }.to raise_error("Connections stop_thread method not implemented")
        tf.unlink
      end
    end

    describe "connect" do
      it "should call start_thread with no parameters" do
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE MY_INT interface.rb'
        tf.close
        interfaces = Connections.new(:INTERFACES, CmdTlmServerConfig.new(tf.path))
        expect(interfaces).to receive(:start_thread)
        interfaces.connect("MY_INT")
        tf.unlink
      end

      it "should call disconnect, recreate and start_thread with parameters" do
        allow_any_instance_of(Interface).to receive(:disconnect)
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE MY_INT interface.rb'
        tf.close
        interfaces = Connections.new(:INTERFACES, CmdTlmServerConfig.new(tf.path))
        expect(interfaces).to receive(:stop_thread)
        expect(interfaces).to receive(:start_thread)
        expect(interfaces).to receive(:recreate)
        interfaces.connect("MY_INT", "param")
        tf.unlink
      end
    end

    describe "recreate" do
      it "should raise an error" do
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE MY_INT interface.rb'
        tf.close
        interfaces = Connections.new(:INTERFACES, CmdTlmServerConfig.new(tf.path))
        expect { interfaces.recreate("MY_INT") }.to raise_error("Connections recreate method not implemented")
        tf.unlink
      end
    end

    describe "state" do
      it "should relay the state of the connection" do
        allow_any_instance_of(Interface).to receive(:connected?).and_return(false, true, false)
        allow_any_instance_of(Interface).to receive(:thread).and_return(true, nil)

        tf = Tempfile.new('unittest')
        tf.puts 'ROUTER MY_ROUTER interface.rb'
        tf.close
        routers = Connections.new(:ROUTERS, CmdTlmServerConfig.new(tf.path))
        routers.state("MY_ROUTER").should eql "ATTEMPTING"
        routers.state("MY_ROUTER").should eql "CONNECTED"
        routers.state("MY_ROUTER").should eql "DISCONNECTED"
        tf.unlink
      end
    end

    describe "names" do
      it "should list all the names" do
        tf = Tempfile.new('unittest')
        tf.puts 'ROUTER ROUTER1 interface.rb'
        tf.puts 'ROUTER ROUTER2 interface.rb'
        tf.puts 'ROUTER ROUTER3 interface.rb'
        tf.close
        routers = Connections.new(:ROUTERS, CmdTlmServerConfig.new(tf.path))
        routers.names.should eql %w(ROUTER1 ROUTER2 ROUTER3)
        tf.unlink
      end
    end

    describe "clear_counters" do
      it "should clear all counters" do
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE INTERFACE1 interface.rb'
        tf.puts 'INTERFACE INTERFACE2 interface.rb'
        tf.puts 'INTERFACE INTERFACE3 interface.rb'
        tf.close
        interfaces = Connections.new(:INTERFACES, CmdTlmServerConfig.new(tf.path))
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

