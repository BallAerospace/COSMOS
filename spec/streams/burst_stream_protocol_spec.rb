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
        bsp.bytes_read.should eql 0
        bsp.bytes_written.should eql 0
        bsp.interface.should be_nil
        bsp.stream.should be_nil
        bsp.post_read_data_callback.should be_nil
        bsp.post_read_packet_callback.should be_nil
        bsp.pre_write_packet_callback.should be_nil
      end
    end
  end
end

