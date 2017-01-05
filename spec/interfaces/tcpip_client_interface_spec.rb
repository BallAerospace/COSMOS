# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/tcpip_client_interface'

module Cosmos
  describe TcpipClientInterface do
    describe "initialize" do
      it "is not writeable if no write port given" do
        i = TcpipClientInterface.new('localhost','nil','8889','nil','5','burst')
        expect(i.name).to eql "Cosmos::TcpipClientInterface"
        expect(i.write_allowed?).to be false
        expect(i.write_raw_allowed?).to be false
        expect(i.read_allowed?).to be true
      end

      it "is not readable if no read port given" do
        i = TcpipClientInterface.new('localhost','8888','nil','5','nil','burst')
        expect(i.name).to eql "Cosmos::TcpipClientInterface"
        expect(i.write_allowed?).to be true
        expect(i.write_raw_allowed?).to be true
        expect(i.read_allowed?).to be false
      end
    end

    describe "connect" do
      it "passes a new TcpipClientStream to the stream protocol" do
        stream = double("stream")
        allow(stream).to receive(:connect)
        expect(TcpipClientStream).to receive(:new) { stream }
        expect(stream).to receive(:connected?) { true }
        expect(stream).to receive(:raw_logger_pair=) { nil }
        i = TcpipClientInterface.new('localhost','8888','8889','5','5','burst')
        expect(i.connected?).to be false
        i.connect
        expect(i.connected?).to be true
      end
    end
  end
end
