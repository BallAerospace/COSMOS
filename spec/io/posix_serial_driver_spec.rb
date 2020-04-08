# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

if RbConfig::CONFIG['target_os'] !~ /mswin|mingw|cygwin/i and RUBY_ENGINE == 'ruby' and !ENV['TRAVIS']

  require 'spec_helper'
  require 'cosmos/io/posix_serial_driver'

  module Cosmos

    describe PosixSerialDriver do
      describe "instance" do
        it "enforces the baud rate to a known value" do
          expect { PosixSerialDriver.new('/dev/ttyS0',10,:NONE) }.to raise_error(ArgumentError, "Invalid baud rate: 10")
        end

        it "supports even, odd, or no parity" do
          expect { PosixSerialDriver.new('/dev/ttyS0',9600,:EVEN).close }.to_not raise_error
          expect { PosixSerialDriver.new('/dev/ttyS0',9600,:ODD).close }.to_not raise_error
          expect { PosixSerialDriver.new('/dev/ttyS0',9600,:NONE).close }.to_not raise_error
          expect { PosixSerialDriver.new('/dev/ttyS0',9600,:BLAH) }.to raise_error(ArgumentError, "Invalid parity: BLAH")
        end

        it "supports 1 or 2 stop bits" do
          expect { PosixSerialDriver.new('/dev/ttyS0',9600,:NONE,1).close }.to_not raise_error
          expect { PosixSerialDriver.new('/dev/ttyS0',9600,:NONE,2).close }.to_not raise_error
          expect { PosixSerialDriver.new('/dev/ttyS0',9600,:NONE,3) }.to raise_error(ArgumentError, "Invalid stop bits: 3")
        end

        it "supports 5-8 data bits" do
          (5..8).each do |data_bits|
            driver = PosixSerialDriver.new('/dev/ttyS0',9600,:NONE,1,10,nil,:NONE,data_bits)
            handle = driver.instance_variable_get(:@handle)
            expect(handle.tcgetattr.cflag & Termios::CSIZE).to eq(Termios.const_get("CS#{data_bits}"))
            driver.close
          end
          expect { PosixSerialDriver.new('/dev/ttyS0',9600,:NONE,1,10,nil,:NONE,9) }.to raise_error(ArgumentError, "Invalid data bits: 9")
        end

        it "sets arbitrary Posix structure elements" do
          driver = PosixSerialDriver.new('/dev/ttyS0',9600,:NONE,1,10,nil,:NONE,8)
          handle = driver.instance_variable_get(:@handle)
          # Verify non of the things we're going to set are already set
          expect(handle.tcgetattr.iflag & Termios::IGNBRK).to eq(0)
          expect(handle.tcgetattr.oflag & Termios::OPOST).to eq(0)
          expect(handle.tcgetattr.cflag & Termios::CLOCAL).to eq(Termios::CLOCAL) # We set this by default
          expect(handle.tcgetattr.lflag & Termios::ECHO).to eq(0)
          expect(handle.tcgetattr.cc[Termios::VMIN]).to eq(1)
          driver.close
          # When setting a field the "1" is optional. When clearing a field the "0" is required.
          # Entries in the "cc" special characters field are automatically converted to integers if they are numbers
          struct = [["iflag", "IGNBRK"], ["oflag", "OPOST", "1"], ["cflag", "CLOCAL", "0"], ["lflag", "ECHO"], ["cc", "VMIN", "2"]]
          driver = PosixSerialDriver.new('/dev/ttyS0',9600,:NONE,1,10,nil,:NONE,8,struct)
          handle = driver.instance_variable_get(:@handle)
          expect(handle.tcgetattr.iflag & Termios::IGNBRK).to eq(Termios::IGNBRK)
          expect(handle.tcgetattr.oflag & Termios::OPOST).to eq(Termios::OPOST)
          expect(handle.tcgetattr.cflag & Termios::CLOCAL).to eq(0)
          expect(handle.tcgetattr.lflag & Termios::ECHO).to eq(Termios::ECHO)
          expect(handle.tcgetattr.cc[Termios::VMIN]).to eq(2)
          driver.close
        end
      end

      describe "close, closed?" do
        it "closes the handle" do
          driver = PosixSerialDriver.new('/dev/ttyS0',9600)
          expect(driver.closed?).to be false
          driver.close
          expect(driver.closed?).to be true
        end
      end
    end
  end
end
