# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/io/json_drb'
require 'cosmos/io/json_rpc'

module Cosmos

  describe JsonDRb do
    before(:each) do
      @json = JsonDRb.new
    end

    describe "initialize" do
      it "sets request_count and num_clients to 0" do
        expect(@json.request_count).to eql 0
        expect(@json.num_clients).to eql 0
      end
    end

    describe "acl" do
      it "sets the access control list" do
        acl = ACL.new(['allow','127.0.0.1'], ACL::ALLOW_DENY)
        @json.acl = acl
        expect(@json.acl).to eql acl
      end
    end

    describe "method_whitelist" do
      it "sets the method whitelist" do
        @json.method_whitelist = ['cmd']
        expect(@json.method_whitelist).to eql ['cmd']
      end
    end

    describe "add_request_time, average_request_time" do
      it "adds time to the list and return the average" do
        @json.add_request_time(1.0)
        @json.add_request_time(2.0)
        @json.add_request_time(3.0)
        expect(@json.average_request_time).to eql 2.0
      end
    end

    describe "start_service" do
      it "does nothing when passed no parameters" do
        expect(@json.thread).to be_nil
        @json.start_service()
        expect(@json.thread).to be_nil
      end

      it "raises an error when passed incomplete parameters" do
        expect(@json.thread).to be_nil
        expect { @json.start_service('127.0.0.1') }.to raise_error
        expect { @json.start_service('127.0.0.1', 7777) }.to raise_error
        expect(@json.thread).to be_nil
      end

      it "raises an error when passed a bad host" do
        capture_io do |stdout|
          expect(@json.thread).to be_nil
          system_exit_count = $system_exit_count
          @json.start_service('blah', 7777, self)
          thread = @json.thread
          expect($system_exit_count).to eql(system_exit_count + 1)
          sleep 0.1

          expect(stdout.string).to match /listen thread/
          @json.stop_service
          sleep(0.1)
        end

        Dir[File.join(Cosmos::USERPATH,"*_exception.txt")].each do |file|
          File.delete file
        end
      end

      it "creates a single listen thread" do
        expect(@json.thread).to be_nil
        @json.start_service('127.0.0.1', 7777, self)
        expect(@json.thread.alive?).to be_truthy
        expect { @json.start_service('127.0.0.1', 7777, self) }.to raise_error(/Error binding to port/)
        @json.stop_service
        sleep(0.1)
      end

      it "rescues listen thread exceptions" do
        capture_io do |stdout|
          allow_any_instance_of(TCPServer).to receive(:accept_nonblock) { raise "BLAH" }
          @json.start_service('127.0.0.1', 7777, self)
          socket = TCPSocket.open('127.0.0.1',7777)
          sleep 0.1
          @json.stop_service
          sleep(0.1)

          expect(stdout.string).to match /JsonDRb listen thread unexpectedly died/
        end

        Dir[File.join(Cosmos::USERPATH,"*_exception.txt")].each do |file|
          File.delete file
        end
      end

      it "ignores connections via the ACL" do
        @json.acl = ACL.new(['deny','127.0.0.1'], ACL::ALLOW_DENY)
        @json.start_service('127.0.0.1', 7777, self)
        socket = TCPSocket.open('127.0.0.1',7777)
        sleep 0.1
        expect(socket.eof?).to be_truthy
        socket.close
        @json.stop_service
        sleep(0.1)
      end
    end

    describe "receive_message" do
      it "returns nil if 4 bytes of data aren't available" do
        @json.start_service('127.0.0.1', 7777, self)
        socket = TCPSocket.open('127.0.0.1',7777)
        # Stub read_nonblock so it returns nothing
        allow(socket).to receive(:read_nonblock) { "" }
        sleep 0.1
        JsonDRb.send_data(socket, "\x00")
        response_data = JsonDRb.receive_message(socket, '')
        expect(response_data).to be_nil
        socket.close
        sleep 0.1
        @json.stop_service
        sleep(0.1)
      end

      it "processes success requests" do
        class MyServer1
          def my_method(param)
          end
        end

        @json.start_service('127.0.0.1', 7777, MyServer1.new)
        socket = TCPSocket.open('127.0.0.1',7777)
        sleep 0.1
        request = JsonRpcRequest.new('my_method', 'param', 1).to_json
        JsonDRb.send_data(socket, request)
        response_data = JsonDRb.receive_message(socket, '')
        response = JsonRpcResponse.from_json(response_data)
        expect(response).to be_a(JsonRpcSuccessResponse)
        socket.close
        sleep 0.1
        @json.stop_service
        sleep(0.1)
      end

      it "processes bad methods" do
        class MyServer2
        end

        @json.start_service('127.0.0.1', 7777, MyServer2.new)
        socket = TCPSocket.open('127.0.0.1',7777)
        sleep 0.1
        request = JsonRpcRequest.new('my_method', 'param', 1).to_json
        JsonDRb.send_data(socket, request)
        response_data = JsonDRb.receive_message(socket, '')
        response = JsonRpcResponse.from_json(response_data)
        expect(response).to be_a(JsonRpcErrorResponse)
        expect(response.error.code).to eql -32601
        expect(response.error.message).to eql "Method not found"
        socket.close
        sleep 0.1
        @json.stop_service
        sleep(0.1)
      end

      it "processes bad parameters" do
        class MyServer3
          def my_method(param1, param2)
          end
        end

        @json.start_service('127.0.0.1', 7777, MyServer3.new)
        socket = TCPSocket.open('127.0.0.1',7777)
        sleep 0.1
        request = JsonRpcRequest.new('my_method', 'param1', 1).to_json
        JsonDRb.send_data(socket, request)
        response_data = JsonDRb.receive_message(socket, '')
        response = JsonRpcResponse.from_json(response_data)
        expect(response).to be_a(JsonRpcErrorResponse)
        expect(response.error.code).to eql -32602
        expect(response.error.message).to eql "Invalid params"
        socket.close
        sleep 0.1
        @json.stop_service
        sleep(0.1)
      end

      it "handles method exceptions" do
        class MyServer4
          def my_method(param)
            raise "Method Error"
          end
        end

        @json.start_service('127.0.0.1', 7777, MyServer4.new)
        socket = TCPSocket.open('127.0.0.1',7777)
        sleep 0.1
        request = JsonRpcRequest.new('my_method', 'param', 1).to_json
        JsonDRb.send_data(socket, request)
        response_data = JsonDRb.receive_message(socket, '')
        response = JsonRpcResponse.from_json(response_data)
        expect(response).to be_a(JsonRpcErrorResponse)
        expect(response.error.code).to eql -1
        expect(response.error.message).to eql "Method Error"
        socket.close
        sleep 0.1
        @json.stop_service
        sleep(0.1)
      end

      it "does not allow dangerous methods" do
        @json.start_service('127.0.0.1', 7777, self)
        socket = TCPSocket.open('127.0.0.1',7777)
        sleep 0.1
        request = JsonRpcRequest.new('send', 'param', 1).to_json
        JsonDRb.send_data(socket, request)
        response_data = JsonDRb.receive_message(socket, '')
        response = JsonRpcResponse.from_json(response_data)
        expect(response).to be_a(JsonRpcErrorResponse)
        expect(response.error.code).to eql -1
        expect(response.error.message).to eql "Cannot call unauthorized methods"
        socket.close
        sleep 0.1
        @json.stop_service
        sleep(0.1)
      end

      it "handles an invalid JsonDRB request" do
        @json.start_service('127.0.0.1', 7777, self)
        socket = TCPSocket.open('127.0.0.1',7777)
        sleep 0.1
        request = JsonRpcRequest.new('send', 'param', 1).to_json
        request.gsub!("jsonrpc","version")
        request.gsub!("2.0","1.1")
        JsonDRb.send_data(socket, request)
        response_data = JsonDRb.receive_message(socket, '')
        response = JsonRpcResponse.from_json(response_data)
        expect(response).to be_a(JsonRpcErrorResponse)
        expect(response.error.code).to eql -32600
        expect(response.error.message).to eql "Invalid Request"
        socket.close
        sleep 0.1
        @json.stop_service
        sleep(0.1)
      end
    end

    describe "send_data" do
      it "retries if the socket blocks" do
        @json.start_service('127.0.0.1', 7777, self)
        socket = TCPSocket.open('127.0.0.1',7777)
        # Stub write_nonblock so it blocks
        $index = 0
        allow(socket).to receive(:write_nonblock) do
          case $index
          when 0
            $index += 1
            raise Errno::EWOULDBLOCK
          when 1
            $index += 1
            5
          end
        end
        JsonDRb.send_data(socket, "\x00")
        socket.close
        @json.stop_service
        sleep(0.1)
      end

      it "eventuallies timeout if the socket blocks" do
        @json.start_service('127.0.0.1', 7777, self)
        socket = TCPSocket.open('127.0.0.1',7777)
        # Stub write_nonblock so it blocks
        $index = 0
        allow(socket).to receive(:write_nonblock) do
          raise Errno::EWOULDBLOCK
        end
        allow(IO).to receive(:select) { nil }
        expect { JsonDRb.send_data(socket, "\x00", 2) }.to raise_error(Timeout::Error)
        socket.close
        @json.stop_service
        sleep(0.1)
      end
    end

    describe "debug, debug?" do
      it "sets the debug level" do
        JsonDRb.debug = true
        expect(JsonDRb.debug?).to be_truthy
        JsonDRb.debug = false
        expect(JsonDRb.debug?).to be_falsey
      end
    end

  end
end

