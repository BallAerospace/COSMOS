# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
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
      it "should initialize the instance variables" do
        i = TcpipClientInterface.new('localhost','8888','8889','5','5','burst')
      end

      it "should not be writeable if no write port given" do
        i = TcpipClientInterface.new('localhost','nil','8889','nil','5','burst')
        i.name.should eql "Cosmos::TcpipClientInterface"
        i.write_allowed?.should be_falsey
        i.write_raw_allowed?.should be_falsey
        i.read_allowed?.should be_truthy
      end

      it "should not be readable if no read port given" do
        i = TcpipClientInterface.new('localhost','8888','nil','5','nil','burst')
        i.name.should eql "Cosmos::TcpipClientInterface"
        i.write_allowed?.should be_truthy
        i.write_raw_allowed?.should be_truthy
        i.read_allowed?.should be_falsey
      end
    end

    describe "connect" do
      it "should pass a new TcpipClientStream to the stream protocol" do
        stream = double("stream")
        expect(TcpipClientStream).to receive(:new) { stream }
        expect(stream).to receive(:connected?) { true }
        expect(stream).to receive(:raw_logger_pair=) { nil }
        i = TcpipClientInterface.new('localhost','8888','8889','5','5','burst')
        i.connected?.should be_falsey
        i.connect
        i.connected?.should be_truthy
      end
    end
  end
end

