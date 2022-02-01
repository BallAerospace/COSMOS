# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
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
require 'cosmos/interfaces/linc_interface'

module Cosmos
  xdescribe LincInterface do
    saved_verbose = $VERBOSE; $VERBOSE = nil
    class TcpipClientStream < TcpipSocketStream
      # Allow the connect_nonblock method to simply return
      def connect_nonblock(socket, addr); end

      def write(data); end
    end
    $VERBOSE = saved_verbose

    describe "connect" do
      it "passes a new TcpipClientStream to the stream protocol" do
        i = LincInterface.new('localhost', '8888')
        i.target_names << "INST"
        expect(i.connected?).to be false
        i.connect
        expect(i.connected?).to be true
      end
    end

    describe "write" do
      before(:each) do
        @i = LincInterface.new('localhost', '8888', 'true', '2', 'nil', '5', '0', '16', '4', 'GSE_HDR_GUID', 'BIG_ENDIAN', 'GSE_HDR_LEN')
        @i.target_names << "INST"
        @i.connect
      end

      it "returns an exception if its not connected" do
        i = LincInterface.new('localhost', '8888')
        expect { i.write(Packet.new("TGT", "PKT")) }.to raise_error("Interface not connected")
      end

      it "adds to the ignored list upon an error ignore command" do
        cmd = System.commands.packet("INST", "COSMOS_ERROR_IGNORE")
        cmd.restore_defaults
        cmd.write("CODE", 0x55)
        @i.write(cmd)
        expect(@i.instance_variable_get(:@ignored_error_codes)["INST"]).to include(0x55)
      end

      it "removes from the ignored list upon an error handle command" do
        @i.instance_variable_get(:@ignored_error_codes)["INST"] << 0x66
        expect(@i.instance_variable_get(:@ignored_error_codes)["INST"]).to include(0x66)
        cmd = System.commands.packet("INST", "COSMOS_ERROR_HANDLE")
        cmd.restore_defaults
        cmd.write("CODE", 0x66)
        @i.write(cmd)
        expect(@i.instance_variable_get(:@ignored_error_codes)["INST"]).not_to include(0x66)
      end

      it "enables and disable handshakes upon command" do
        enable = System.commands.packet("INST", "COSMOS_HANDSHAKE_EN")
        enable.restore_defaults
        disable = System.commands.packet("INST", "COSMOS_HANDSHAKE_DS")
        disable.restore_defaults

        @i.write(enable)
        expect(@i.instance_variable_get(:@handshake_enabled)).to be true
        @i.write(disable)
        expect(@i.instance_variable_get(:@handshake_enabled)).to be false
        @i.write(enable)
        expect(@i.instance_variable_get(:@handshake_enabled)).to be true
      end

      it "timeouts waiting for handshake" do
        cmd = System.commands.packet("INST", "LINC_COMMAND")
        cmd.restore_defaults
        expect { @i.write(cmd) }.to raise_error(/Timeout/)
      end

      it "does not timeout if handshakes disabled" do
        disable = System.commands.packet("INST", "COSMOS_HANDSHAKE_DS")
        disable.restore_defaults
        @i.write(disable)

        cmd = System.commands.packet("INST", "LINC_COMMAND")
        cmd.restore_defaults
        @i.write(cmd)
      end

      context "with successful handshake" do
        before(:each) do
          @cmd = System.commands.packet("INST", "LINC_COMMAND")
          @cmd.restore_defaults
          @cmd.write("GSE_HDR_GUID", 0xDEADBEEF)
          @cmd.write("DATA", 1)
          @handshake = System.telemetry.packet("INST", "HANDSHAKE")
          @handshake.write("GSE_HDR_ID", 1001)
          @handshake.write("STATUS", "OK")
          @handshake.write("CODE", 12345)
          @buffer = ''
          @buffer << ["INST".length].pack("C")
          @buffer << "INST"
          @buffer << ["LINC_COMMAND".length].pack("C")
          @buffer << "LINC_COMMAND"
          @buffer << [@cmd.buffer.length].pack("N")
          @buffer << @cmd.buffer
          @buffer << [3].pack("N")
          @buffer << "BAD"
          @handshake.write("DATA", @buffer)
          # LincInterface has a length offset of 4
          @handshake.write("GSE_HDR_LEN", @handshake.buffer(false).length - 4)
        end

        it "does not timeout if the handshake is received" do
          allow_any_instance_of(TcpipClientStream).to receive(:read).and_return @handshake.buffer(false)
          t = Thread.new do
            sleep 0.1
            @i.read
          end
          @i.write(@cmd)
          t.join
        end

        it "handles two simultaneous writes" do
          cmd2 = @cmd.clone
          cmd2.write("GSE_HDR_GUID", 0xBA5EBA11)
          cmd2.write("DATA", 2)
          handshake2 = @handshake.clone
          handshake2.write("GSE_HDR_ID", 1001)
          buffer = ''
          buffer << ["INST".length].pack("C")
          buffer << "INST"
          buffer << ["LINC_COMMAND".length].pack("C")
          buffer << "LINC_COMMAND"
          buffer << [cmd2.buffer.length].pack("N")
          buffer << cmd2.buffer
          buffer << [3].pack("N")
          buffer << "BAD"
          handshake2.write("DATA", buffer)
          handshake2.write("GSE_HDR_LEN", handshake2.buffer(false).length - 4)

          read_cnt = 0
          write_cnt = 0
          allow_any_instance_of(TcpipClientStream).to receive(:read) do
            read_cnt += 1
            result = nil
            result = handshake2.buffer(false) if read_cnt == 1
            result = @handshake.buffer(false) if read_cnt == 2
            result
          end

          # Create new thread for each write
          t1 = Thread.new do
            write_cnt += 1
            @i.write(cmd2)
          end
          # Create new thread for each write
          t2 = Thread.new do
            write_cnt += 1
            @i.write(@cmd)
          end

          sleep 0.2
          # Expect both write threads have written
          expect(write_cnt).to eql 2
          # But no handshakes have been received
          expect(read_cnt).to eql 0

          # Now read the handshakes and allow the reads to complete
          @i.read
          @i.read
          t1.join
          t2.join
          expect(read_cnt).to eql 2
        end

        it "warns if an error code is set" do
          allow_any_instance_of(TcpipClientStream).to receive(:read).and_return @handshake.buffer(false)
          expect(Logger).to receive(:warn) do |msg|
            expect(msg).to eql "LincInterface: Warning sending command (12345): BAD"
          end
          t = Thread.new do
            sleep 0.1
            @i.read
          end
          @i.write(@cmd)
          t.join
        end

        it "raises an exception if the status is 'ERROR'" do
          allow_any_instance_of(TcpipClientStream).to receive(:read).and_return @handshake.buffer(false)
          @handshake.write("STATUS", "ERROR")
          t = Thread.new do
            sleep 0.1
            @i.read
          end
          expect { @i.write(@cmd) }.to raise_error("Error sending command (12345): BAD")
          t.join
        end
      end
    end

    describe "read" do
      before(:each) do
        @i = LincInterface.new('localhost', '8888', 'true', '2', 'nil', '5', '0', '16', '4', 'GSE_HDR_GUID', 'BIG_ENDIAN', 'GSE_HDR_LEN')
        @i.target_names << "INST"
        expect(@i.connected?).to be false
        @i.connect
        expect(@i.connected?).to be true
      end

      it "handles local commands" do
        @handshake = System.telemetry.packet("INST", "HANDSHAKE")
        @handshake.write("GSE_HDR_ID", 1001)
        @handshake.write("STATUS", "OK")
        @handshake.write("CODE", 12345)
        @handshake.write("ORIGIN", 1)
        buffer = ''
        buffer << ["INST".length].pack("C")
        buffer << "INST"
        buffer << ["LINC_COMMAND".length].pack("C")
        buffer << "LINC_COMMAND"
        buffer << [@handshake.buffer.length].pack("N")
        buffer << @handshake.buffer
        buffer << [3].pack("N")
        buffer << "BAD"
        @handshake.write("DATA", buffer)
        # LincInterface has a length offset of 4
        @handshake.write("GSE_HDR_LEN", @handshake.buffer(false).length - 4)

        allow_any_instance_of(TcpipClientStream).to receive(:read).and_return @handshake.buffer(false)

        expect(Logger).to receive(:info) do |msg|
          expect(msg).to match(/External Command/)
        end

        @i.read
      end
    end
  end
end
