# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/io/win32_serial_driver'

module Cosmos

  describe Win32SerialDriver do
    before(:each) do
      allow(Win32).to receive(:create_file).and_return(Object.new)
      state = double("comm_state")
      allow(state).to receive(:write)
      allow(Win32).to receive(:get_comm_state).and_return(state)
      allow(Win32).to receive(:set_comm_state)
      allow(Win32).to receive(:set_comm_timeouts)
    end

    describe "instance" do
      it "should enforce the baud rate to a known value" do
        expect { Win32SerialDriver.new('COM1',10,:NONE) }.to raise_error(ArgumentError, "Invalid baud rate: 10")
      end

      it "should support even, odd, or no parity" do
        expect { Win32SerialDriver.new('COM1',9600,:EVEN) }.to_not raise_error
        expect { Win32SerialDriver.new('COM1',9600,:ODD) }.to_not raise_error
        expect { Win32SerialDriver.new('COM1',9600,:NONE) }.to_not raise_error
        expect { Win32SerialDriver.new('COM1',9600,:BLAH) }.to raise_error(ArgumentError, "Invalid parity: BLAH")
      end

      it "should support 1 or 2 stop bits" do
        expect { Win32SerialDriver.new('COM1',9600,:NONE,1) }.to_not raise_error
        expect { Win32SerialDriver.new('COM1',9600,:NONE,2) }.to_not raise_error
        expect { Win32SerialDriver.new('COM1',9600,:NONE,3) }.to raise_error(ArgumentError, "Invalid stop bits: 3")
      end
    end

    describe "close, closed?" do
      it "should close the handle" do
        expect(Win32).to receive(:close_handle)
        driver = Win32SerialDriver.new('COM1',9600)
        driver.closed?.should be_falsey
        driver.close
        driver.closed?.should be_truthy
      end
    end

    describe "write" do
      it "should handle write errors" do
        expect(Win32).to receive(:write_file).and_return 0
        driver = Win32SerialDriver.new('COM1',9600)
        expect { driver.write('\x00') }.to raise_error("Error writing to comm port")
      end

      it "should use the write timeout" do
        expect(Win32).to receive(:write_file) do
          sleep 2
          1
        end
        driver = Win32SerialDriver.new('COM1',9600,:NONE,1,1)
        expect { driver.write('\x00\x01') }.to raise_error(Timeout::Error)
      end
    end

    describe "read" do
      it "return the data read" do
        expect(Win32).to receive(:read_file) { '\x00' }
        driver = Win32SerialDriver.new('COM1',9600,:NONE,1,1,nil,0.01,1)
        driver.read.should eql '\x00'
      end

      it "should use the read timeout" do
        allow(Win32).to receive(:read_file) { '' }
        driver = Win32SerialDriver.new('COM1',9600,:NONE,1,1,1.0,0.5,10)
        expect { driver.read }.to raise_error(Timeout::Error)
      end
    end

  end
end

