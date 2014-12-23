# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
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
      it "should set request_count and num_clients to 0" do
        @json.request_count.should eql 0
        @json.num_clients.should eql 0
      end
    end

    describe "acl" do
      it "should set the access control list" do
        acl = ACL.new(['allow','127.0.0.1'], ACL::ALLOW_DENY)
        @json.acl = acl
        @json.acl.should eql acl
      end
    end

    describe "method_whitelist" do
      it "should set the method whitelist" do
        @json.method_whitelist = ['cmd']
        @json.method_whitelist.should eql ['cmd']
      end
    end

    describe "add_request_time, average_request_time" do
      it "should add time to the list and return the average" do
        @json.add_request_time(1.0)
        @json.add_request_time(2.0)
        @json.add_request_time(3.0)
        @json.average_request_time.should eql 2.0
      end
    end

    describe "start_service" do
      it "should do nothing when passed no parameters" do
        @json.thread.should be_nil
        @json.start_service()
        @json.thread.should be_nil
      end

      it "should raise an error when passed incomplete parameters" do
        @json.thread.should be_nil
        expect { @json.start_service('127.0.0.1') }.to raise_error
        expect { @json.start_service('127.0.0.1', 7777) }.to raise_error
        @json.thread.should be_nil
      end

      it "should raise an error when passed a bad host" do
        capture_io do |stdout|
          @json.thread.should be_nil
          system_exit_count = $system_exit_count
          @json.start_service('blah', 7777, self)
          $system_exit_count.should eql(system_exit_count + 1)
          sleep 0.1

          stdout.string.should match /listen thread/
        end

        Dir[File.join(Cosmos::USERPATH,"*_exception.txt")].each do |file|
          File.delete file
        end
      end

      it "should create a single listen thread" do
        @json.thread.should be_nil
        @json.start_service('127.0.0.1', 7777, self)
        @json.thread.alive?.should be_truthy
        expect { @json.start_service('127.0.0.1', 7777, self) }.to raise_error(/Error binding to port/)
        @json.stop_service
      end

      it "should rescue listen thread exceptions" do
        capture_io do |stdout|
          allow_any_instance_of(TCPServer).to receive(:accept) { raise "BLAH" }
          @json.start_service('127.0.0.1', 7777, self)
          socket = TCPSocket.open('127.0.0.1',7777)
          sleep 0.1
          @json.stop_service

          stdout.string.should match /JsonDRb listen thread unexpectedly died/
        end

        Dir[File.join(Cosmos::USERPATH,"*_exception.txt")].each do |file|
          File.delete file
        end
      end

      it "should ignore connections via the ACL" do
        @json.acl = ACL.new(['deny','127.0.0.1'], ACL::ALLOW_DENY)
        @json.start_service('127.0.0.1', 7777, self)
        socket = TCPSocket.open('127.0.0.1',7777)
        sleep 0.1
        socket.eof?.should be_truthy
        @json.stop_service
      end
    end

    describe "receive_message" do
      it "should return nil if 4 bytes of data aren't available" do
        @json.start_service('127.0.0.1', 7777, self)
        socket = TCPSocket.open('127.0.0.1',7777)
        # Stub recv_nonblock so it returns nothing
        allow(socket).to receive(:recv_nonblock) { "" }
        sleep 0.1
        JsonDRb.send_data(socket, "\x00")
        response_data = JsonDRb.receive_message(socket, '')
        response_data.should be_nil
        socket.close
        sleep 0.1
        @json.stop_service
      end

      it "should process success requests" do
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
        response.should be_a(JsonRpcSuccessResponse)
        socket.close
        sleep 0.1
        @json.stop_service
      end

      it "should process bad methods" do
        class MyServer2
        end

        @json.start_service('127.0.0.1', 7777, MyServer2.new)
        socket = TCPSocket.open('127.0.0.1',7777)
        sleep 0.1
        request = JsonRpcRequest.new('my_method', 'param', 1).to_json
        JsonDRb.send_data(socket, request)
        response_data = JsonDRb.receive_message(socket, '')
        response = JsonRpcResponse.from_json(response_data)
        response.should be_a(JsonRpcErrorResponse)
        response.error.code.should eql -32601
        response.error.message.should eql "Method not found"
        socket.close
        sleep 0.1
        @json.stop_service
      end

      it "should process bad parameters" do
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
        response.should be_a(JsonRpcErrorResponse)
        response.error.code.should eql -32602
        response.error.message.should eql "Invalid params"
        socket.close
        sleep 0.1
        @json.stop_service
      end

      it "should handle method exceptions" do
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
        response.should be_a(JsonRpcErrorResponse)
        response.error.code.should eql -1
        response.error.message.should eql "Method Error"
        socket.close
        sleep 0.1
        @json.stop_service
      end

      it "should not allow dangerous methods" do
        @json.start_service('127.0.0.1', 7777, self)
        socket = TCPSocket.open('127.0.0.1',7777)
        sleep 0.1
        request = JsonRpcRequest.new('send', 'param', 1).to_json
        JsonDRb.send_data(socket, request)
        response_data = JsonDRb.receive_message(socket, '')
        response = JsonRpcResponse.from_json(response_data)
        response.should be_a(JsonRpcErrorResponse)
        response.error.code.should eql -1
        response.error.message.should eql "Cannot call unauthorized methods"
        socket.close
        sleep 0.1
        @json.stop_service
      end

      it "should handle an invalid JsonDRB request" do
        @json.start_service('127.0.0.1', 7777, self)
        socket = TCPSocket.open('127.0.0.1',7777)
        sleep 0.1
        request = JsonRpcRequest.new('send', 'param', 1).to_json
        request.gsub!("jsonrpc","version")
        request.gsub!("2.0","1.1")
        JsonDRb.send_data(socket, request)
        response_data = JsonDRb.receive_message(socket, '')
        response = JsonRpcResponse.from_json(response_data)
        response.should be_a(JsonRpcErrorResponse)
        response.error.code.should eql -32600
        response.error.message.should eql "Invalid Request"
        socket.close
        sleep 0.1
        @json.stop_service
      end
    end

    describe "send_data" do
      it "should retry if the socket blocks" do
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
        @json.stop_service
      end

      it "should eventually timeout if the socket blocks" do
        @json.start_service('127.0.0.1', 7777, self)
        socket = TCPSocket.open('127.0.0.1',7777)
        # Stub write_nonblock so it blocks
        $index = 0
        allow(socket).to receive(:write_nonblock) do
          raise Errno::EWOULDBLOCK
        end
        allow(IO).to receive(:select) { nil }
        expect { JsonDRb.send_data(socket, "\x00", 2) }.to raise_error(Timeout::Error)
        @json.stop_service
      end
    end

    describe "debug, debug?" do
      it "should set the debug level" do
        JsonDRb.debug = true
        JsonDRb.debug?.should be_truthy
        JsonDRb.debug = false
        JsonDRb.debug?.should be_falsey
      end
    end

  end
end

