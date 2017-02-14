# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
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
        DOC
      end
    end

    after(:all) do
      File.delete(File.join(File.dirname(__FILE__),'..','..','lib','test_inst.rb'))
    end

    describe "initialize" do
      it "complains if the simulated target file doesn't exist" do
        expect { SimulatedTargetInterface.new("does_not_exist.rb") }.to raise_error(/Unable to require does_not_exist.rb/)
      end

      it "creates the simulated target class" do
        SimulatedTargetInterface.new("test_inst.rb")
      end
    end

    describe "connect" do
      it "creates the simulated target" do
        sti = SimulatedTargetInterface.new("test_inst.rb")
        sti.target_names = ['COSMOS']
        sti.connect
      end
    end

    describe "connected?" do
      it "initiallies be false" do
        sti = SimulatedTargetInterface.new("test_inst.rb")
        sti.target_names = ['COSMOS']
        expect(sti.connected?).to be false
        sti.connect
        expect(sti.connected?).to be true
      end
    end

    describe "read" do
      it "complains if disconnected" do
        expect { SimulatedTargetInterface.new("test_inst.rb").read }.to raise_error("Interface not connected")
      end

      it "returns a simulated packet" do
        sti = SimulatedTargetInterface.new("test_inst.rb")
        sti.target_names = ['COSMOS']
        expect(sti.connected?).to be false
        sti.connect
        pkt = sti.read
        expect(pkt.target_name).to eql "COSMOS"
        expect(pkt.packet_name).to eql "VERSION"
        pkt = sti.read
        expect(pkt.target_name).to eql "COSMOS"
        expect(pkt.packet_name).to eql "VERSION"
      end
    end

    describe "write" do
      it "complains if disconnected" do
        expect { SimulatedTargetInterface.new("test_inst.rb").write(nil) }.to raise_error("Interface not connected")
      end

      it "writes commands to the simulator" do
        sti = SimulatedTargetInterface.new("test_inst.rb")
        sti.target_names = ['COSMOS']
        expect(sti.connected?).to be false
        sti.connect
        sti.write(Packet.new("COSMOS","SETLOGLABEL"))
      end
    end

    describe "write_raw" do
      it "raises an exception" do
        expect { SimulatedTargetInterface.new("test_inst.rb").write_raw("") }.to raise_error(/not implemented/)
      end
    end

    describe "disconnect" do
      it "disconnects from the simulator" do
        sti = SimulatedTargetInterface.new("test_inst.rb")
        sti.target_names = ['COSMOS']
        expect(sti.connected?).to be false
        sti.connect
        expect(sti.connected?).to be true
        sti.disconnect
        expect(sti.connected?).to be false
      end
    end

  end
end

