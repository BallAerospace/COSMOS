# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'spec_helper'
require 'cosmos/conversions/new_packet_log_conversion'
require 'cosmos/packets/packet'

module Cosmos

  describe NewPacketLogConversion do

    describe "call" do
      it "returns the value given and call start_logging" do
        cmd_tlm_server = double("CmdTlmServer", :packet_logging => '')
        allow(CmdTlmServer).to receive(:instance).and_return(cmd_tlm_server)
        expect(cmd_tlm_server).to receive(:start_logging).with('ALL')
        conversion = NewPacketLogConversion.new('ALL')
        packet = Packet.new("TGT","PKT")
        packet.append_item("TIME",32,:UINT)
        expect(conversion.call(5,packet,packet.buffer)).to eql 5
      end
    end

    describe "to_s" do
      it "returns the conversion and packet_log_writer_name" do
        conversion = NewPacketLogConversion.new('BOB')
        expect(conversion.to_s).to eql "NewPacketLogConversion (BOB)"
      end
    end
  end
end
