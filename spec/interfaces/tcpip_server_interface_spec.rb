# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/tcpip_server_interface'

module Cosmos

  describe TcpipServerInterface do
    describe "initialize" do
      it "initializes the instance variables" do
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        expect(i.name).to eql "TcpipServerInterface"
      end

      it "is not writeable if no write port given" do
        i = TcpipServerInterface.new('nil','8889','nil','5','burst')
        expect(i.write_allowed?).to be false
        expect(i.write_raw_allowed?).to be false
        expect(i.read_allowed?).to be true
      end

      it "is not readable if no read port given" do
        i = TcpipServerInterface.new('8888','nil','5','nil','burst')
        expect(i.write_allowed?).to be true
        expect(i.write_raw_allowed?).to be true
        expect(i.read_allowed?).to be false
      end
    end

    describe "read" do
      it "counts the packets received" do
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        class << i
          def connected?; true; end
        end

        read_queue = i.instance_variable_get(:@read_queue)
        2.times { read_queue << Packet.new(nil, nil) }

        expect(i.read_count).to eql 0
        i.read
        expect(i.read_count).to eql 1
        i.read
        expect(i.read_count).to eql 2
      end

      it "does not count nil packets" do
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        class << i
          def connected?; true; end
        end

        read_queue = i.instance_variable_get(:@read_queue)
        2.times { read_queue << nil }

        expect(i.read_count).to eql 0
        i.read
        expect(i.read_count).to eql 0
        i.read
        expect(i.read_count).to eql 0
      end
    end

    describe "write" do
      it "complains if the server is not connected" do
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        class << i
          def connected?; false; end
        end
        expect { i.write(Packet.new('','')) }.to raise_error(/Interface not connected/)
      end

      it "counts the packets written" do
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        class << i
          def connected?; true; end
        end
        expect(i.write_count).to eql 0
        i.write(Packet.new('',''))
        expect(i.write_count).to eql 1
        i.write(Packet.new('',''))
        expect(i.write_count).to eql 2
      end
    end

    describe "write_raw" do
      it "complains if the server is not connected" do
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        class << i
          def connected?; false; end
        end
        expect { i.write_raw("\x00") }.to raise_error(/Interface not connected/)
      end

      it "counts the bytes written" do
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        i.connect
        sleep(1)
        write_interface_infos = i.instance_variable_get(:@write_interface_infos)
        wii = TcpipServerInterface::InterfaceInfo.new(StreamInterface.new, nil, nil, nil)
        interface = wii.interface
        class << interface
          def connected?; true; end
          def write_interface(data); write_interface_base(data); end
          def stream
            a = Object.new
            class << a
              def write_socket
                b = Object.new
                class << b
                  def recvfrom_nonblock(amount)
                    raise Errno::EWOULDBLOCK
                  end
                end
                b
              end
            end
            a
          end
        end
        write_interface_infos << wii
        begin
          expect(i.write_count).to eql 0
          expect(i.bytes_written).to eql 0
          i.write_raw("\x00\x01")
          sleep(1)
          expect(i.write_count).to eql 0
          expect(i.bytes_written).to eql 2
          i.write_raw("\x02")
          sleep(1)
          expect(i.write_count).to eql 0
          expect(i.bytes_written).to eql 3
        ensure
          i.disconnect
        end
      end
    end

    describe "set_option" do
      it "sets the listen address for the tcpip_server" do
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        i.set_option('LISTEN_ADDRESS', ['127.0.0.1'])
        expect(i.instance_variable_get(:@listen_address)).to eq '127.0.0.1'
      end
    end

  end
end

