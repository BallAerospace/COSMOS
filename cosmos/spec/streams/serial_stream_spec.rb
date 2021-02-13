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
require 'cosmos/streams/serial_stream'

module Cosmos

  if RUBY_ENGINE == 'ruby' or Gem.win_platform?

    describe SerialStream do
      describe "initialize" do
        it "complains if neither a read or write port given" do
          expect { SerialStream.new(nil,nil,9600,:EVEN,1,nil,nil) }.to raise_error("Either a write port or read port must be given")
        end
      end

      describe "connected?" do
        it "is connected when initialized" do
          driver = double("driver")
          expect(SerialDriver).to receive(:new).and_return(driver)
          ss = SerialStream.new('COM1',nil,9600,:EVEN,1,nil,nil)
          expect(ss.connected?).to be true
        end
      end

      describe "read" do
        it "raises an error if no read port given" do
          driver = double("driver")
          expect(SerialDriver).to receive(:new).and_return(driver)
          ss = SerialStream.new('COM1',nil,9600,:EVEN,1,nil,nil)
          expect { ss.read }.to raise_error("Attempt to read from write only stream")
        end

        it "calls read from the driver" do
          driver = double("driver")
          expect(driver).to receive(:read).and_return 'test'
          expect(SerialDriver).to receive(:new).and_return(driver)
          ss = SerialStream.new('COM1','COM1',9600,:EVEN,1,nil,nil)
          expect(ss.read).to eql 'test'
        end
      end

      describe "write" do
        it "raises an error if no write port given" do
          driver = double("driver")
          expect(SerialDriver).to receive(:new).and_return(driver)
          ss = SerialStream.new(nil,'COM1',9600,:EVEN,1,nil,nil)
          expect { ss.write('') }.to raise_error("Attempt to write to read only stream")
        end

        it "calls write from the driver" do
          driver = double("driver")
          expect(driver).to receive(:write).with('test')
          expect(SerialDriver).to receive(:new).and_return(driver)
          ss = SerialStream.new('COM1','COM1',9600,:EVEN,1,nil,nil)
          ss.write('test')
        end
      end

      describe "disconnect" do
        it "closes the write driver" do
          driver = double("driver")
          expect(driver).to receive(:closed?).and_return(false)
          expect(driver).to receive(:close)
          expect(SerialDriver).to receive(:new).and_return(driver)
          ss = SerialStream.new('COM1',nil,9600,:EVEN,1,nil,nil)
          expect(ss.connected?).to be true
          ss.disconnect
          expect(ss.connected?).to be false
        end

        it "closes the read driver" do
          driver = double("driver")
          expect(driver).to receive(:closed?).and_return(false)
          expect(driver).to receive(:close)
          expect(SerialDriver).to receive(:new).and_return(driver)
          ss = SerialStream.new(nil,'COM1',9600,:EVEN,1,nil,nil)
          expect(ss.connected?).to be true
          ss.disconnect
          expect(ss.connected?).to be false
        end

        it "does not close the driver twice" do
          driver = double("driver")
          expect(driver).to receive(:closed?).and_return(false, true)
          expect(driver).to receive(:close).once
          expect(SerialDriver).to receive(:new).and_return(driver)
          ss = SerialStream.new('COM1','COM1',9600,:EVEN,1,nil,nil)
          expect(ss.connected?).to be true
          ss.disconnect
          expect(ss.connected?).to be false
          ss.disconnect
          expect(ss.connected?).to be false
        end
      end

      describe "connect" do
        it "supports a connect method that does nothing" do
          driver = double("driver")
          expect(driver).to receive(:closed?).and_return(false)
          expect(driver).to receive(:close).once
          expect(SerialDriver).to receive(:new).and_return(driver)
          ss = SerialStream.new(nil,'COM1',9600,:EVEN,1,nil,nil)
          expect {ss.connect}.to_not raise_error
          ss.disconnect
        end
      end
    end

  end

end
