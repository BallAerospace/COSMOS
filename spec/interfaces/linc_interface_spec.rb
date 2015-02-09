# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/linc_interface'

module Cosmos

  describe LincInterface do
    before(:all) do
      clean_config()
      System.class_eval('@@instance = nil')
    end

    describe "connect" do
      it "should pass a new TcpipClientStream to the stream protocol" do
        stream = double("stream")
        allow(stream).to receive(:connect)
        expect(TcpipClientStream).to receive(:new) { stream }
        expect(stream).to receive(:connected?) { true }
        expect(stream).to receive(:raw_logger_pair=) { nil }
        i = LincInterface.new('localhost','8888')
        i.target_names << "INST"
        i.connected?.should be_falsey
        i.connect
        i.connected?.should be_truthy
      end
    end

    describe "write" do
      before(:each) do
        stream = double("stream")
        allow(stream).to receive(:connect)
        expect(TcpipClientStream).to receive(:new) { stream }
        allow(stream).to receive(:connected?) { true }
        allow(stream).to receive(:write)
        expect(stream).to receive(:raw_logger_pair=) { nil }
        @i = LincInterface.new('localhost','8888','true','2','nil','5','0','16','4','GSE_HDR_GUID','BIG_ENDIAN','GSE_HDR_LEN')
        @i.target_names << "INST"
        @i.connected?.should be_falsey
        @i.connect
        @i.connected?.should be_truthy
      end

      it "should return an exception if its not connected" do
        i = LincInterface.new('localhost','8888')
        expect { i.write(Packet.new("TGT","PKT")) }.to raise_error("Interface not connected")
      end

      it "should add to the ignored list upon an error ignore command" do
        cmd = System.commands.packet("INST","COSMOS_ERROR_IGNORE")
        cmd.restore_defaults
        cmd.write("CODE", 0x55)
        @i.write(cmd)
        @i.instance_variable_get(:@ignored_error_codes).should include(0x55)
      end

      it "should remove from the ignored list upon an error handle command" do
        @i.instance_variable_get(:@ignored_error_codes) << 0x66
        @i.instance_variable_get(:@ignored_error_codes).should include(0x66)
        cmd = System.commands.packet("INST","COSMOS_ERROR_HANDLE")
        cmd.restore_defaults
        cmd.write("CODE", 0x66)
        @i.write(cmd)
        @i.instance_variable_get(:@ignored_error_codes).should_not include(0x66)
      end

      it "should enable and disable handshakes upon command" do
        enable = System.commands.packet("INST","COSMOS_HANDSHAKE_EN")
        enable.restore_defaults
        disable = System.commands.packet("INST","COSMOS_HANDSHAKE_DS")
        disable.restore_defaults

        @i.write(enable)
        @i.instance_variable_get(:@handshake_enabled).should be_truthy
        @i.write(disable)
        @i.instance_variable_get(:@handshake_enabled).should be_falsey
        @i.write(enable)
        @i.instance_variable_get(:@handshake_enabled).should be_truthy
      end

      it "should timeout waiting for handshake" do
        cmd = System.commands.packet("INST","LINC_COMMAND")
        cmd.restore_defaults
        expect { @i.write(cmd) }.to raise_error(/Timeout/)
      end

      it "should not timeout if handshakes disabled" do
        disable = System.commands.packet("INST","COSMOS_HANDSHAKE_DS")
        disable.restore_defaults
        @i.write(disable)

        cmd = System.commands.packet("INST","LINC_COMMAND")
        cmd.restore_defaults
        @i.write(cmd)
      end

      context "with successful handshake" do
        before(:each) do
          @cmd = System.commands.packet("INST","LINC_COMMAND")
          @cmd.restore_defaults
          @cmd.write("GSE_HDR_GUID",0xDEADBEEF)
          @handshake = System.telemetry.packet("INST","HANDSHAKE")
          @handshake.write("GSE_HDR_ID", 1001)
          @handshake.write("STATUS","OK")
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

          allow_any_instance_of(LengthStreamProtocol).to receive(:read).and_return(@handshake)
        end

        it "should not timeout if the handshake is received" do
          t = Thread.new do
            sleep 1
            @i.read
          end
          @i.write(@cmd)
          t.join
        end

        it "should warn if an error code is set" do
          expect(Logger).to receive(:warn) do |msg|
            msg.should eql "Warning sending command (12345): BAD"
          end
          t = Thread.new do
            sleep 1
            @i.read
          end
          @i.write(@cmd)
          t.join
        end

        it "should raise an exception if the status is 'ERROR'" do
          @handshake.write("STATUS", "ERROR")
          t = Thread.new do
            sleep 1
            @i.read
          end
          expect { @i.write(@cmd) }.to raise_error("Error sending command (12345): BAD")
          t.join
        end
      end
    end

    describe "read" do
      before(:each) do
        stream = double("stream")
        allow(stream).to receive(:connect)
        expect(TcpipClientStream).to receive(:new) { stream }
        allow(stream).to receive(:connected?) { true }
        allow(stream).to receive(:write)
        expect(stream).to receive(:raw_logger_pair=) { nil }
        @i = LincInterface.new('localhost','8888','true','2','nil','5','0','16','4','GSE_HDR_GUID','BIG_ENDIAN','GSE_HDR_LEN')
        @i.target_names << "INST"
        @i.connected?.should be_falsey
        @i.connect
        @i.connected?.should be_truthy
      end

      it "should handle local commands" do
        @handshake = System.telemetry.packet("INST","HANDSHAKE")
        @handshake.write("GSE_HDR_ID", 1001)
        @handshake.write("ORIGIN", 1)

        allow_any_instance_of(LengthStreamProtocol).to receive(:read).and_return(@handshake)

        expect(Logger).to receive(:info) do |msg|
          msg.should match(/External Command/)
        end

        @i.read
      end

      it "should handle response overflows" do
        @handshake = System.telemetry.packet("INST","HANDSHAKE")
        @handshake.write("GSE_HDR_ID", 1001)
        @handshake.write("ORIGIN", 0)
        allow_any_instance_of(LengthStreamProtocol).to receive(:read).and_return(@handshake)
        100.times { @i.read }
        expect { @i.read }.to raise_error
      end
    end

  end
end

