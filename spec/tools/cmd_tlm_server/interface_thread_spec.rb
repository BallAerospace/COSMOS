# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos'
require 'cosmos/tools/cmd_tlm_server/interface_thread'
require 'cosmos/interfaces/interface'

module Cosmos

  describe InterfaceThread do

    before(:each) do
      @packet = Packet.new('TGT','PKT')
      @packet.buffer = "\x01\x02"

      @interface = Interface.new
      @connected_count = 0
      allow(@interface).to receive(:connected?) do
        if @connected_count == 0
          @connected_count += 1
          false
        else
          @connected_count += 1
          true
        end
      end
      allow(@interface).to receive(:connect)
      allow(@interface).to receive(:disconnect)
      allow(@interface).to receive(:read) do
        sleep 0.01
        @packet
      end

      allow(System).to receive_message_chain(:telemetry,:identify!).and_return(nil)
      allow(System).to receive_message_chain(:telemetry,:update!).and_return(@packet)
      targets = {'TGT'=>Target.new('TGT')}
      allow(System).to receive(:targets).and_return(targets)
    end

    after(:all) do
      Dir[File.join(Cosmos::USERPATH,"*_exception.txt")].each do |file|
        File.delete file
      end
    end

    describe "start" do
      it "logs connection errors" do
        capture_io do |stdout|
          allow(@interface).to receive(:connected?).and_return(false)
          allow(@interface).to receive(:connect) { raise "ConnectError" }
          thread = InterfaceThread.new(@interface)
          thread.start
          sleep 0.1
          expect(Thread.list.length).to eql(2)
          thread.stop
          sleep 0.2
          expect(Thread.list.length).to eql(1)

          expect(stdout.string).to match "Connection Failed: RuntimeError : ConnectError"
        end
      end

      it "does not log connection errors when there is a callback" do
        capture_io do |stdout|
          allow(@interface).to receive(:connected?).and_return(false)
          allow(@interface).to receive(:connect) { raise "ConnectError" }
          # Make the reconnect_delay be slightly longer than half of 0.1 which is
          # how long the test is waiting after calling start. This allows us to
          # create see the error twice.
          @interface.reconnect_delay = 0.06
          thread = InterfaceThread.new(@interface)
          error_count = 0
          thread.connection_failed_callback = Proc.new do |error|
            expect(error.message).to eql "ConnectError"
            error_count += 1
          end
          thread.start
          sleep 0.1
          expect(Thread.list.length).to eql(2)
          thread.stop
          sleep 0.2
          expect(Thread.list.length).to eql(1)
          expect(error_count).to eql 2

          expect(stdout.string).not_to match "Connection Failed: ConnectError"
        end
      end

      it "logs the connection" do
        capture_io do |stdout|
          thread = InterfaceThread.new(@interface)
          thread.start
          sleep 0.1
          expect(Thread.list.length).to eql(2)
          thread.stop
          sleep 0.2
          expect(Thread.list.length).to eql(1)

          expect(stdout.string).to match "Connection Success"
        end
      end

      it "does not log the connection when there is a callback" do
        capture_io do |stdout|
          thread = InterfaceThread.new(@interface)
          callback_called = false
          thread.connection_success_callback = Proc.new do
            callback_called = true
          end
          thread.start
          sleep 0.1
          expect(Thread.list.length).to eql(2)
          thread.stop
          sleep 0.2
          expect(Thread.list.length).to eql(1)
          expect(callback_called).to be_truthy

          expect(stdout.string).not_to match "Connection Success"
        end
      end

      it "logs the connection being lost" do
        capture_io do |stdout|
          allow(@interface).to receive(:read).and_return(nil)
          # Make the reconnect_delay be slightly longer than half of 0.1 which is
          # how long the test is waiting after calling start. This allows us to
          # create see the error twice.
          @interface.reconnect_delay = 0.06
          thread = InterfaceThread.new(@interface)
          thread.start
          sleep 0.1
          expect(Thread.list.length).to eql(2)
          thread.stop
          sleep 0.2
          expect(Thread.list.length).to eql(1)

          expect(stdout.string).to match "Connection Lost"
        end
      end

      it "does not log the connection being lost when there is a callback" do
        capture_io do |stdout|
          allow(@interface).to receive(:read).and_return(nil)
          @interface.auto_reconnect = false
          thread = InterfaceThread.new(@interface)
          callback_called = false
          thread.connection_lost_callback = Proc.new do
            callback_called = true
          end
          thread.start
          sleep 1
          # Since we set auto_reconnect to false we shouldn't see the interface
          # thread because it will be killed
          expect(Thread.list.length).to eql(1)
          thread.stop
          sleep 0.2
          expect(Thread.list.length).to eql(1)
          expect(callback_called).to be_truthy

          expect(stdout.string).not_to match "Connection Lost"
        end
      end

      it "handles a read exception" do
        capture_io do |stdout|
          allow(@interface).to receive(:read) { raise "ReadError" }
          thread = InterfaceThread.new(@interface)
          thread.start
          sleep 0.1
          expect(Thread.list.length).to eql(2)
          thread.stop
          sleep 0.2
          expect(Thread.list.length).to eql(1)

          expect(stdout.string).to match "ReadError"
        end
      end

      it "handles a read connection reset" do
        capture_io do |stdout|
          allow(@interface).to receive(:read) { raise Errno::ECONNRESET }
          # Make the reconnect_delay be slightly longer than half of 0.1 which is
          # how long the test is waiting after calling start. This allows us to
          # create see the error twice.
          @interface.reconnect_delay = 0.06
          thread = InterfaceThread.new(@interface)
          thread.start
          sleep 0.1
          expect(Thread.list.length).to eql(2)
          thread.stop
          sleep 0.2
          expect(Thread.list.length).to eql(1)

          expect(stdout.string).to match "ECONNRESET"
        end
      end

      it "logs any thread exceptions" do
        capture_io do |stdout|
          allow(@interface).to receive(:connected?) { raise "ConnectedError" }
          thread = InterfaceThread.new(@interface)
          thread.start
          sleep 0.1
          thread.stop
          sleep 0.2

          expect(stdout.string).to match "Packet reading thread unexpectedly died"
        end
      end

      it "does not thread exceptions when there is a callback" do
        capture_io do |stdout|
          allow(@interface).to receive(:connected?) { raise "ConnectedError" }
          thread = InterfaceThread.new(@interface)
          callback_called = false
          thread.fatal_exception_callback = Proc.new do |error|
            expect(error.message).to eql "ConnectedError"
            callback_called = true
          end
          thread.start
          sleep 0.1
          thread.stop
          sleep 0.2
          expect(callback_called).to be_truthy

          expect(stdout.string).not_to match "Packet reading thread unexpectedly died"
        end
      end

      it "handles unidentified packets" do
        capture_io do |stdout|
          @packet = Packet.new(nil,nil)
          thread = InterfaceThread.new(@interface)
          thread.start
          sleep 0.1
          expect(Thread.list.length).to eql(2)
          thread.stop
          sleep 0.2
          expect(Thread.list.length).to eql(1)

          expect(stdout.string).to match "Unknown 2 byte packet"
        end
      end

      it "handles identified yet unknown telemetry" do
        capture_io do |stdout|
          @packet.target_name = 'BOB'
          @packet.packet_name = 'SMITH'
          allow(System).to receive_message_chain(:telemetry,:update!).and_raise(RuntimeError)
          thread = InterfaceThread.new(@interface)
          thread.start
          sleep 0.1
          expect(Thread.list.length).to eql(2)
          thread.stop
          sleep 0.2
          expect(Thread.list.length).to eql(1)
          expect(stdout.string).to match "Received unknown identified telemetry: BOB SMITH"
        end
      end

      it "writes to all defined routers" do
        capture_io do |stdout|
          router = double("Router")
          allow(router).to receive(:write_allowed?).and_return(true)
          allow(router).to receive(:connected?).and_return(true)
          allow(router).to receive(:name).and_return("ROUTER")
          allow(router).to receive(:write) { raise "RouterWriteError" }
          @interface.routers = [router]
          thread = InterfaceThread.new(@interface)
          thread.start
          sleep 0.1
          expect(Thread.list.length).to eql(2)
          thread.stop
          sleep 0.2
          expect(Thread.list.length).to eql(1)

          expect(stdout.string).to match "Problem writing to router"
        end
      end

      it "writes to all defined packet log writers" do
        writer = double("LogWriter")
        allow(writer).to receive_message_chain(:tlm_log_writer,:write)
        @interface.packet_log_writer_pairs = [writer]
        thread = InterfaceThread.new(@interface)
        threads = Thread.list.length
        thread.start
        sleep 0.1
        expect(Thread.list.length).to eql(2)
        thread.stop
        sleep 0.2
        expect(Thread.list.length).to eql(1)
      end

    end
  end
end

