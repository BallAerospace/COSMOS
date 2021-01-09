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
require 'cosmos/processors/processor'

module Cosmos
  describe NewPacketLogProcessor do
    describe "initialize" do
      it "takes a packet log writer name" do
        a = NewPacketLogProcessor.new('MINE')
        expect(a.value_type).to eql :CONVERTED
      end
    end

    describe "call" do
      xit "starts logging" do
        log_name = nil
        allow(CmdTlmServer).to receive_message_chain(:instance,:start_logging) do |name|
          log_name = name
        end
        a = NewPacketLogProcessor.new()
        a.call(nil, nil)
        expect(log_name).to eql('ALL')
      end
    end
  end
end
