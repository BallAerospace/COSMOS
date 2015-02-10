# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/streams/serial_stream'

module Cosmos

  describe SerialStream do
    describe "initialize" do
      it "should complain if neither a read or write port given" do
        expect { SerialStream.new(nil,nil,9600,:EVEN,1,nil,nil) }.to raise_error("Either a write port or read port must be given")
      end
    end

    describe "connected?" do
      it "should be connected when initialized" do
        driver = double("driver")
        expect(SerialDriver).to receive(:new).and_return(driver)
        ss = SerialStream.new('COM1',nil,9600,:EVEN,1,nil,nil)
        ss.connected?.should be_truthy
      end
    end

    describe "read" do
      it "should raise an error if no read port given" do
        driver = double("driver")
        expect(SerialDriver).to receive(:new).and_return(driver)
        ss = SerialStream.new('COM1',nil,9600,:EVEN,1,nil,nil)
        expect { ss.read }.to raise_error("Attempt to read from write only stream")
      end

      it "should call read from the driver" do
        driver = double("driver")
        expect(driver).to receive(:read).and_return 'test'
        expect(SerialDriver).to receive(:new).and_return(driver)
        ss = SerialStream.new('COM1','COM1',9600,:EVEN,1,nil,nil)
        ss.read.should eql 'test'
      end
    end

    describe "write" do
      it "should raise an error if no write port given" do
        driver = double("driver")
        expect(SerialDriver).to receive(:new).and_return(driver)
        ss = SerialStream.new(nil,'COM1',9600,:EVEN,1,nil,nil)
        expect { ss.write('') }.to raise_error("Attempt to write to read only stream")
      end

      it "should call write from the driver" do
        driver = double("driver")
        expect(driver).to receive(:write).with('test')
        expect(SerialDriver).to receive(:new).and_return(driver)
        ss = SerialStream.new('COM1','COM1',9600,:EVEN,1,nil,nil)
        ss.write('test')
      end
    end

    describe "disconnect" do
      it "should close the write driver" do
        driver = double("driver")
        expect(driver).to receive(:closed?).and_return(false)
        expect(driver).to receive(:close)
        expect(SerialDriver).to receive(:new).and_return(driver)
        ss = SerialStream.new('COM1',nil,9600,:EVEN,1,nil,nil)
        ss.connected?.should be_truthy
        ss.disconnect
        ss.connected?.should be_falsey
      end

      it "should close the read driver" do
        driver = double("driver")
        expect(driver).to receive(:closed?).and_return(false)
        expect(driver).to receive(:close)
        expect(SerialDriver).to receive(:new).and_return(driver)
        ss = SerialStream.new(nil,'COM1',9600,:EVEN,1,nil,nil)
        ss.connected?.should be_truthy
        ss.disconnect
        ss.connected?.should be_falsey
      end

      it "shouldn't close the driver twice" do
        driver = double("driver")
        expect(driver).to receive(:closed?).and_return(false, true)
        expect(driver).to receive(:close).once
        expect(SerialDriver).to receive(:new).and_return(driver)
        ss = SerialStream.new('COM1','COM1',9600,:EVEN,1,nil,nil)
        ss.connected?.should be_truthy
        ss.disconnect
        ss.connected?.should be_falsey
        ss.disconnect
        ss.connected?.should be_falsey
      end
    end

    describe "connect" do
      it "should support a connect method that does nothing" do
        driver = double("driver")
        expect(driver).to receive(:closed?).and_return(false)
        expect(driver).to receive(:close).once
        expect(SerialDriver).to receive(:new).and_return(driver)
        ss = SerialStream.new(nil,'COM1',9600,:EVEN,1,nil,nil)
        expect{ss.connect}.to_not raise_error
        ss.disconnect
      end
    end

  end
end

