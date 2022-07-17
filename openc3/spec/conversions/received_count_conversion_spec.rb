# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'spec_helper'
require 'openc3/conversions/received_count_conversion'
require 'openc3/packets/packet'

module OpenC3
  describe ReceivedCountConversion do
    describe "initialize" do
      it "initializes converted_type and converted_bit_size" do
        gc = ReceivedCountConversion.new()
        expect(gc.converted_type).to eql :UINT
        expect(gc.converted_bit_size).to eql 32
      end
    end

    describe "call" do
      it "calls the code to eval and return the result" do
        gc = ReceivedCountConversion.new()
        packet = Packet.new("TGT", "PKT")
        packet.received_count = 100
        expect(gc.call(nil, packet, nil)).to eql 100
      end
    end

    describe "to_s" do
      it "returns the class" do
        expect(ReceivedCountConversion.new().to_s).to eql "ReceivedCountConversion"
      end
    end
  end
end
