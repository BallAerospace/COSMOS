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
require 'httpclient'

module Cosmos

  describe JsonDRb do
    before(:each) do
      @json = JsonDRb.new
      @pipe_reader, @pipe_writer = IO.pipe
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

      it "can be started again after stopping" do
        @json.start_service('127.0.0.1', 7777, self)
        @json.stop_service
        @json.start_service('127.0.0.1', 7777, self)
        @json.stop_service
        expect { @json.start_service('blah', 7777, self) }.to raise_error(/JsonDRb http server could not be started/)
        @json.stop_service
        @json.start_service('127.0.0.1', 7777, self)
        @json.stop_service
      end

      it "does nothing when passed no parameters" do
        expect(@json.thread).to be_nil
        @json.start_service()
        expect(@json.thread).to be_nil
      end

      it "raises an error when passed incomplete parameters" do
        expect(@json.thread).to be_nil
        expect { @json.start_service('127.0.0.1') }.to raise_error(/3 parameters must be given/)
        expect { @json.start_service('127.0.0.1', 7777) }.to raise_error(/3 parameters must be given/)
        expect(@json.thread).to be_nil
      end

      it "raises an error when passed a bad host" do
        capture_io do |stdout|
          expect(@json.thread).to be_nil
          system_exit_count = $system_exit_count
          expect { @json.start_service('blah', 7777, self) }.to raise_error(/JsonDRb http server could not be started/)
          sleep 5
          expect($system_exit_count).to eql(system_exit_count + 1)
          expect(stdout.string).to match(/JsonDRb http server could not be started or unexpectedly died/)
          @json.stop_service
          sleep(0.1)
        end

        Dir[File.join(Cosmos::USERPATH,"*_exception.txt")].each do |file|
          File.delete file
        end
      end

      it "raises an error if the server doesn't start" do
        allow(Rack::Handler::Puma).to receive(:run) {}
        expect { @json.start_service('127.0.0.1', 7777, self) }.to raise_error(/JsonDRb http server could not be started/)
      end

      it "creates a single listen thread" do
        expect(@json.thread).to be_nil
        @json.start_service('127.0.0.1', 7777, self)
        sleep(1)
        expect(@json.thread.alive?).to be true
        num_threads = running_threads.length
        @json.start_service('127.0.0.1', 7777, self)
        sleep(1)
        expect(running_threads.length).to eql num_threads
        @json.stop_service
        sleep(0.1)
      end

      it "rescues listen thread exceptions" do
        capture_io do |stdout|
          allow(Rack::Handler::Puma).to receive(:run) { raise "BLAH" }
          expect { @json.start_service('127.0.0.1', 7777, self) }.to raise_error(/JsonDRb http server could not be started/)
          sleep(0.1)
          @json.stop_service
          sleep(0.1)

          expect(stdout.string).to match(/JsonDRb http server could not be started or unexpectedly died/)
        end

        Dir[File.join(Cosmos::USERPATH,"*_exception.txt")].each do |file|
          File.delete file
        end
      end

      it "rejects posts via the ACL" do
        @json.acl = ACL.new(['deny','127.0.0.1'], ACL::ALLOW_DENY)
        @json.start_service('127.0.0.1', 7777, self)
        client = HTTPClient.new
        res = client.post("http://127.0.0.1:7777", "")
        expect(res.status).to eq 403
        expect(res.body).to match(/Forbidden/)
        @json.stop_service
        sleep(0.1)
      end
    end

    describe "process_request" do
      it "processes success requests" do
        class MyServer1
          def my_method(param)
          end
        end

        @json.start_service('127.0.0.1', 7777, MyServer1.new)
        request_data = JsonRpcRequest.new('my_method', 'param', 1).to_json
        _, error_code = @json.process_request(request_data, Time.now)
        expect(error_code).to eq nil
        @json.stop_service
        sleep(0.1)
      end

      it "processes bad methods" do
        class MyServer2
        end

        @json.start_service('127.0.0.1', 7777, MyServer2.new)
        request_data = JsonRpcRequest.new('my_method', 'param', 1).to_json
        response_data, error_code = @json.process_request(request_data, Time.now)
        expect(error_code).to eql -32601
        expect(response_data).to match(/Method not found/)
        @json.stop_service
        sleep(0.1)
      end

      it "processes bad parameters" do
        class MyServer3
          def my_method(param1, param2)
          end
        end

        @json.start_service('127.0.0.1', 7777, MyServer3.new)
        request_data = JsonRpcRequest.new('my_method', 'param1', 1).to_json
        response_data, error_code = @json.process_request(request_data, Time.now)
        expect(error_code).to eql -32602
        expect(response_data).to match(/Invalid params/)
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
        request_data = JsonRpcRequest.new('my_method', 'param', 1).to_json
        response_data, error_code = @json.process_request(request_data, Time.now)
        expect(error_code).to eql -1
        expect(response_data).to match(/Method Error/)
        @json.stop_service
        sleep(0.1)
      end

      it "processes success requests with uppercase" do
        class MyServer5
          def my_method(param)
          end
        end

        @json.start_service('127.0.0.1', 7777, MyServer5.new)
        request_data = JsonRpcRequest.new('MY_METHOD', 'param', 1).to_json
        _, error_code = @json.process_request(request_data, Time.now)
        expect(error_code).to eq nil
        @json.stop_service
        sleep(0.1)
      end

      it "does not allow dangerous methods" do
        @json.start_service('127.0.0.1', 7777, self)
        request_data = JsonRpcRequest.new('send', 'param', 1).to_json
        response_data, error_code = @json.process_request(request_data, Time.now)
        expect(error_code).to eql -1
        expect(response_data).to match(/Cannot call unauthorized methods/)
        @json.stop_service
        sleep(0.1)
      end

      it "handles an invalid JsonDRB request" do
        @json.start_service('127.0.0.1', 7777, self)
        request_data = JsonRpcRequest.new('send', 'param', 1).to_json
        request_data.gsub!("jsonrpc","version")
        request_data.gsub!("2.0","1.1")
        response_data, error_code = @json.process_request(request_data, Time.now)
        expect(error_code).to eql -32600
        expect(response_data).to match(/Invalid Request/)
        @json.stop_service
        sleep(0.1)
      end
    end

    describe "debug, debug?" do
      it "sets the debug level" do
        JsonDRb.debug = true
        expect(JsonDRb.debug?).to be true
        JsonDRb.debug = false
        expect(JsonDRb.debug?).to be false
      end
    end

  end
end

