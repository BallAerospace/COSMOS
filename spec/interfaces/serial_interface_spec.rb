# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/serial_interface'

module Cosmos

  describe SerialInterface do

    describe "initialize" do
      it "initializes the instance variables" do
        i = SerialInterface.new('COM1','COM1','9600','NONE','1','0','0','burst')
        expect(i.name).to eql "Cosmos::SerialInterface"
      end

      it "is not writeable if no write port given" do
        i = SerialInterface.new('nil','COM1','9600','NONE','1','0','0','burst')
        expect(i.name).to eql "Cosmos::SerialInterface"
        expect(i.write_allowed?).to be_falsey
        expect(i.write_raw_allowed?).to be_falsey
        expect(i.read_allowed?).to be_truthy
      end

      it "is not readable if no read port given" do
        i = SerialInterface.new('COM1','nil','9600','NONE','1','0','0','burst')
        expect(i.name).to eql "Cosmos::SerialInterface"
        expect(i.write_allowed?).to be_truthy
        expect(i.write_raw_allowed?).to be_truthy
        expect(i.read_allowed?).to be_falsey
      end
    end

    describe "connect" do
      it "passes a new SerialStream to the stream protocol" do
        # Ensure the 'NONE' parity is coverted to a symbol
        if Kernel.is_windows?
          i = SerialInterface.new('COM1','COM1','9600','NONE','1','0','0','burst')
          expect(i.connected?).to be_falsey
          i.connect
          expect(i.connected?).to be_truthy
          i.disconnect
          expect(i.connected?).to be_falsey
        end
      end
    end
  end
end

