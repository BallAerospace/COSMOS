# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/streams/burst_stream_protocol'

module Cosmos

  describe BurstStreamProtocol do

    describe "initialize" do
      it "initializes attributes" do
        bsp = BurstStreamProtocol.new
        expect(bsp.bytes_read).to eql 0
        expect(bsp.bytes_written).to eql 0
        expect(bsp.interface).to be_a Interface
        expect(bsp.stream).to be_nil
      end
    end
  end
end

