# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
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
      it "should initialize the instance variables" do
        i = SerialInterface.new('COM1','COM1','9600','NONE','1','0','0','burst')
        i.name.should eql "Cosmos::SerialInterface"
      end

      it "should not be writeable if no write port given" do
        i = SerialInterface.new('nil','COM1','9600','NONE','1','0','0','burst')
        i.name.should eql "Cosmos::SerialInterface"
        i.write_allowed?.should be_falsey
        i.write_raw_allowed?.should be_falsey
        i.read_allowed?.should be_truthy
      end

      it "should not be readable if no read port given" do
        i = SerialInterface.new('COM1','nil','9600','NONE','1','0','0','burst')
        i.name.should eql "Cosmos::SerialInterface"
        i.write_allowed?.should be_truthy
        i.write_raw_allowed?.should be_truthy
        i.read_allowed?.should be_falsey
      end
    end

    describe "connect" do
      it "should pass a new SerialStream to the stream protocol" do
        # Ensure the 'NONE' parity is coverted to a symbol
        if Kernel.is_windows?
          i = SerialInterface.new('COM1','COM1','9600','NONE','1','0','0','burst')
          i.connected?.should be_falsey
          i.connect
          i.connected?.should be_truthy
          i.disconnect
          i.connected?.should be_falsey
        end
      end
    end
  end
end

