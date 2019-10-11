# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

if RUBY_ENGINE == 'ruby' or Gem.win_platform?

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
        it "enforces the baud rate to a known value" do
          expect { Win32SerialDriver.new('COM1',10,:NONE) }.to raise_error(ArgumentError, "Invalid baud rate: 10")
        end

        it "supports even, odd, or no parity" do
          expect { Win32SerialDriver.new('COM1',9600,:EVEN) }.to_not raise_error
          expect { Win32SerialDriver.new('COM1',9600,:ODD) }.to_not raise_error
          expect { Win32SerialDriver.new('COM1',9600,:NONE) }.to_not raise_error
          expect { Win32SerialDriver.new('COM1',9600,:BLAH) }.to raise_error(ArgumentError, "Invalid parity: BLAH")
        end

        it "supports 1 or 2 stop bits" do
          expect { Win32SerialDriver.new('COM1',9600,:NONE,1) }.to_not raise_error
          expect { Win32SerialDriver.new('COM1',9600,:NONE,2) }.to_not raise_error
          expect { Win32SerialDriver.new('COM1',9600,:NONE,3) }.to raise_error(ArgumentError, "Invalid stop bits: 3")
        end

        it "supports 5-8 data bits" do
          expect { Win32SerialDriver.new('COM1',9600,:NONE,1,10,nil,0.01,1000,:NONE,5) }.to_not raise_error
          expect { Win32SerialDriver.new('COM1',9600,:NONE,1,10,nil,0.01,1000,:NONE,6) }.to_not raise_error
          expect { Win32SerialDriver.new('COM1',9600,:NONE,1,10,nil,0.01,1000,:NONE,7) }.to_not raise_error
          expect { Win32SerialDriver.new('COM1',9600,:NONE,1,10,nil,0.01,1000,:NONE,8) }.to_not raise_error
          expect { Win32SerialDriver.new('COM1',9600,:NONE,1,10,nil,0.01,1000,:NONE,9) }.to raise_error(ArgumentError, "Invalid data bits: 9")
        end

        it "calculates the correct timeouts" do
          Win32::BAUD_RATES.each do |baud|
            (5..8).each do |data_bits|
              (1..2).each do |stop_bits|
                [:EVEN, :ODD, :NONE].each do |parity|
                  # data_bits + 1 start bit + stop bits + potentially a parity bit
                  symbols = data_bits + 1 + stop_bits + (parity == :NONE ? 0 : 1)
                  delay = 1000.0 / (baud.to_f / symbols)
                  expect(Win32).to receive(:set_comm_timeouts).with(anything, 0xFFFFFFFF,0,0,delay.ceil,1000)
                  Win32SerialDriver.new('COM1',baud,parity,stop_bits,10,nil,0.01,1000,:NONE,data_bits)
                end
              end
            end
          end
        end
      end

      describe "close, closed?" do
        it "closes the handle" do
          expect(Win32).to receive(:close_handle)
          driver = Win32SerialDriver.new('COM1',9600)
          expect(driver.closed?).to be false
          driver.close
          expect(driver.closed?).to be true
        end
      end

      describe "write" do
        it "handles write errors" do
          expect(Win32).to receive(:write_file).and_return 0
          driver = Win32SerialDriver.new('COM1',9600)
          expect { driver.write('\x00') }.to raise_error("Error writing to comm port")
        end

        it "uses the write timeout" do
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
          expect(driver.read).to eql '\x00'
        end

        it "uses the read timeout" do
          allow(Win32).to receive(:read_file) { '' }
          driver = Win32SerialDriver.new('COM1',9600,:NONE,1,1,1.0,0.5,10)
          expect { driver.read }.to raise_error(Timeout::Error)
        end
      end
    end
  end
end
