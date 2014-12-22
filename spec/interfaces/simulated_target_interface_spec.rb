# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/simulated_target_interface'

module Cosmos

  describe SimulatedTargetInterface do

    before(:all) do
      File.open(File.join(File.dirname(__FILE__),'..','..','lib','test_inst.rb'),'w') do |file|
        file.puts <<-DOC
require 'cosmos/utilities/simulated_target'
require 'cosmos/packets/packet'
module Cosmos
  class TestInst < SimulatedTarget
    def initialize(target)
      super(target)
    end
    def set_rates
    end
    def write(packet)
    end
    def read(count, time)
      pkts = []
      pkts << Packet.new("COSMOS","VERSION")
      pkts << Packet.new("COSMOS","VERSION")
    end
  end
end
        DOC
      end
    end

    after(:all) do
      File.delete(File.join(File.dirname(__FILE__),'..','..','lib','test_inst.rb'))
    end

    describe "initialize" do
      it "should complain if the simulated target file doesn't exist" do
        expect { SimulatedTargetInterface.new("doesnt_exist.rb") }.to raise_error(/Unable to require doesnt_exist.rb/)
      end

      it "should create the simulated target class" do
        SimulatedTargetInterface.new("test_inst.rb")
      end
    end

    describe "connect" do
      it "should create the simulated target" do
        sti = SimulatedTargetInterface.new("test_inst.rb")
        sti.target_names = ['COSMOS']
        sti.connect
      end
    end

    describe "connected?" do
      it "should initially be false" do
        sti = SimulatedTargetInterface.new("test_inst.rb")
        sti.target_names = ['COSMOS']
        sti.connected?.should be_falsey
        sti.connect
        sti.connected?.should be_truthy
      end
    end

    describe "read" do
      it "should complain if disconnected" do
        expect { SimulatedTargetInterface.new("test_inst.rb").read }.to raise_error("Interface not connected")
      end

      it "should return a simulated packet" do
        sti = SimulatedTargetInterface.new("test_inst.rb")
        sti.target_names = ['COSMOS']
        sti.connected?.should be_falsey
        sti.connect
        pkt = sti.read
        pkt.target_name.should eql "COSMOS"
        pkt.packet_name.should eql "VERSION"
        pkt = sti.read
        pkt.target_name.should eql "COSMOS"
        pkt.packet_name.should eql "VERSION"
      end
    end

    describe "write" do
      it "should complain if disconnected" do
        expect { SimulatedTargetInterface.new("test_inst.rb").write(nil) }.to raise_error("Interface not connected")
      end

      it "should write commands to the simulator" do
        sti = SimulatedTargetInterface.new("test_inst.rb")
        sti.target_names = ['COSMOS']
        sti.connected?.should be_falsey
        sti.connect
        sti.write(Packet.new("COSMOS","SETLOGLABEL"))
      end
    end

    describe "write_raw" do
      it "should raise an exception" do
        expect { SimulatedTargetInterface.new("test_inst.rb").write_raw("") }.to raise_error(/not implemented/)
      end
    end

    describe "disconnect" do
      it "should disconnect from the simulator" do
        sti = SimulatedTargetInterface.new("test_inst.rb")
        sti.target_names = ['COSMOS']
        sti.connected?.should be_falsey
        sti.connect
        sti.connected?.should be_truthy
        sti.disconnect
        sti.connected?.should be_falsey
      end
    end

  end
end

