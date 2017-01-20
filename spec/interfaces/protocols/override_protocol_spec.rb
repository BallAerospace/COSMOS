# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/interface'
require 'cosmos/interfaces/protocols/override_protocol'

module Cosmos
  describe OverrideProtocol do
    let(:interface) { Interface.new.extend(OverrideProtocol) }

    it "overrides INT values" do
      pkt = Packet.new("TGT","PKT")
      rc = GenericConversion.new("value * 2")
      wc = GenericConversion.new("value * 4")
      pkt.append_item("ITEM", 8, :INT, nil, :BIG_ENDIAN, :ERROR, nil, rc, wc)
      expect(pkt.read("ITEM")).to eql(0)

      interface._override_tlm_raw("TGT","PKT","ITEM",-10)
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(-20)

      interface._override_tlm("TGT","PKT","ITEM",-10) # Write conversion writes -40
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(-80) # Read conversion reads -80
    end

    it "overrides UINT values" do
      pkt = Packet.new("TGT","PKT")
      rc = GenericConversion.new("value * 2")
      wc = GenericConversion.new("value * 4")
      pkt.append_item("ITEM", 8, :UINT, nil, :BIG_ENDIAN, :ERROR, nil, rc, wc)
      expect(pkt.read("ITEM")).to eql(0)

      interface._override_tlm_raw("TGT","PKT","ITEM",10)
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(20)

      interface._override_tlm("TGT","PKT","ITEM",10) # Write conversion writes 40
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(80) # Read conversion reads 80
    end

    it "overrides FLOAT values" do
      pkt = Packet.new("TGT","PKT")
      rc = GenericConversion.new("value * 2")
      wc = GenericConversion.new("value * 4")
      pkt.append_item("ITEM", 32, :FLOAT, nil, :BIG_ENDIAN, :ERROR, nil, rc, wc)
      expect(pkt.read("ITEM")).to eql(0.0)

      interface._override_tlm_raw("TGT","PKT","ITEM",10.5)
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(21.0)

      interface._override_tlm("TGT","PKT","ITEM",10.5) # Write conversion writes 42
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(84.0) # Read conversion reads 84
    end

    it "overrides DOUBLE values" do
      pkt = Packet.new("TGT","PKT")
      rc = GenericConversion.new("value * 2")
      wc = GenericConversion.new("value * 4")
      pkt.append_item("ITEM", 32, :FLOAT, nil, :BIG_ENDIAN, :ERROR, nil, rc, wc)
      expect(pkt.read("ITEM")).to eql(0.0)

      interface._override_tlm_raw("TGT","PKT","ITEM",Float::INFINITY)
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(Float::INFINITY)

      interface._override_tlm("TGT","PKT","ITEM",10.5) # Write conversion writes 42
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(84.0) # Read conversion reads 84
    end

    it "overrides STRING values" do
      pkt = Packet.new("TGT","PKT")
      rc = GenericConversion.new("value * 2")
      wc = GenericConversion.new("value * 4")
      pkt.append_item("ITEM", 1024, :STRING, nil, :BIG_ENDIAN, :ERROR, nil, rc, wc)
      expect(pkt.read("ITEM")).to eql("")

      interface._override_tlm_raw("TGT","PKT","ITEM","HI")
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql("HIHI")

      interface._override_tlm("TGT","PKT","ITEM","X") # Write conversion writes XXXX
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql("XXXXXXXX")
    end

    it "clears overriden values" do
      pkt = Packet.new("TGT","PKT")
      rc = GenericConversion.new("value * 2")
      wc = GenericConversion.new("value * 4")
      pkt.append_item("ITEM", 8, :INT, nil, :BIG_ENDIAN, :ERROR, nil, rc, wc)
      expect(pkt.read("ITEM")).to eql(0)

      interface._override_tlm_raw("TGT","PKT","ITEM",-10)
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(-20)

      interface._normalize_tlm("TGT","PKT","ITEM")
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(0)
    end

    it "warns the user if the protocol is not required" do
      cts = File.join(Cosmos::USERPATH,'config','tools','cmd_tlm_server','cmd_tlm_server.txt')
      FileUtils.mkdir_p(File.dirname(cts))
      File.open(cts,'w') do |file|
        file.puts 'INTERFACE INST_INT simulated_target_interface.rb sim_inst.rb'
        file.puts 'TARGET INST'
        # We don't include: PROTOCOL override_protocol.rb
      end
      System.class_eval('@@instance = nil')
      require 'cosmos/script'
      @server = CmdTlmServer.new
      shutdown_cmd_tlm()
      initialize_script_module()
      sleep 0.1

      expect { override_tlm_raw("INST HEALTH_STATUS TEMP3 = 0") }.to raise_error(/INST_INT does not have override_tlm_raw/)

      @server.stop
      shutdown_cmd_tlm()
      sleep(0.1)
      clean_config()
      FileUtils.rm_rf File.join(Cosmos::USERPATH,'config','tools')
    end
  end
end
