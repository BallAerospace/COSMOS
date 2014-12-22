# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/packet_logs/packet_log_writer_pair'

module Cosmos

  describe PacketLogWriterPair do

    describe "initialize" do
      it "should set the cmd writer and tlm writer" do
        cmd = double("cmd_writer")
        tlm = double("tlm_writer")
        pair = PacketLogWriterPair.new(cmd, tlm)
        pair.cmd_log_writer.should eql cmd
        pair.tlm_log_writer.should eql tlm
      end
    end

  end
end

