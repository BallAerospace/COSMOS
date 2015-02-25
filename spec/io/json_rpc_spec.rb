# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/io/json_rpc'

describe Object do
  class Test1
    def initialize
      @test = 0
    end
  end
  class Test2
    def initialize
      @test = 0
    end
    def to_hash
      Hash.new("test"=>0)
    end
  end

  it "implements as_json" do
    Test1.new.as_json.should eql [:@test]
    Test2.new.as_json.should eql Hash.new("test"=>0)
  end
end

describe Struct do
  it "implements as_json" do
    s = Struct.new(:test1, :test2)
    instance = s.new(1,2)
    hash = {"test1"=>1,"test2"=>2}
    instance.as_json.should eql hash
  end
end

describe String do
  it "implements as_json" do
    "test".as_json.should eql "test"
    hash = {"json_class"=>"String","raw"=>[16]}
    "\x10".as_json.should eql hash
  end
end

describe Enumerable do
  class Test
    include Enumerable
    def each
      yield 1
      yield 2
    end
  end

  it "implements as_json" do
    Test.new.as_json.should eql [1,2]
  end
end

describe Array do
  it "implements as_json" do
    [1,2,3].as_json.should eql [1,2,3]
  end
end

describe Hash do
  it "implements as_json" do
    hash = {"true"=>1,"false"=>0}
    hash.as_json.should eql hash
  end
end

describe Time do
  it "implements as_json" do
    time = Time.new(2020,01,31,12,20,10)
    time.as_json.should match "2020-01-31 12:20:10"
  end
end

describe Date do
  it "implements as_json" do
    date = Date.new(2020,01,31)
    date.as_json.should eql "2020-01-31"
  end
end

describe DateTime do
  it "implements as_json" do
    dt = DateTime.new(2020,01,31,12,20,10)
    dt.as_json.should match "2020-01-31T12:20:10"
  end
end

describe Exception do
  class TestError < Exception
    def initialize(message)
      super(message)
      @test = "test"
    end
  end

  it "implements as_json" do
    json = TestError.new("Error").as_json
    json["class"].should eql "TestError"
    json["message"].should eql "Error"
    hash = {"@test"=>"test"}
    json["instance_variables"].should eql hash
  end

  it "calls as_json from to_json" do
    TestError.new("Error").to_json.should be_a String
  end

  it "creates an object from a hash" do
    json = TestError.new("Error").as_json
    error = Exception.from_hash(json)
    error.should be_a TestError
    error.message.should eql "Error"
  end

  it "rescues creating an object" do
    json = TestError.new("Error").as_json
    json["class"] = "ClassWhichDoesNotExist"
    json["message"] = "Error"
    json["backtrace"] = "trace"
    expect { Exception.from_hash(json) }.to raise_error
  end
end

module Cosmos

  describe JsonRpcRequest do
    describe "method" do
      it "returns the method" do
        JsonRpcRequest.new("puts","test",10).method.should eql "puts"
      end
    end

    describe "params" do
      it "returns the parameters" do
        JsonRpcRequest.new("puts",nil,10).params.should eql []
        JsonRpcRequest.new("puts","test",10).params.should eql "test"
        JsonRpcRequest.new("puts",["test",1],10).params.should eql ["test",1]
      end
    end

    describe "id" do
      it "returns the request id" do
        JsonRpcRequest.new("puts",nil,10).id.should eql 10
      end
    end

    describe "as_json" do
      it "returns the json hash" do
        json = JsonRpcRequest.new("puts","test",10).as_json
        json["jsonrpc"].should eql "2.0"
        json["method"].should eql "puts"
        json["params"].should eql "test"
        json["id"].should eql 10
      end
    end

    describe "to_json" do
      it "returns the json string" do
        json = JsonRpcRequest.new("puts","test",10).to_json.should be_a String
      end
    end

    describe "from_json" do
      it "creates a request from the json string" do
        request = JsonRpcRequest.new("puts","test",10)
        request.should == JsonRpcRequest.from_json(request.to_json)
      end

      it "rescues a bad json string" do
        json = JsonRpcRequest.new("puts","test",10).to_json
        json.gsub!("jsonrpc","version")
        json.gsub!("2.0","1.1")
        expect { JsonRpcRequest.from_json(json) }.to raise_error("Invalid JSON-RPC 2.0 Request")
        expect { JsonRpcRequest.from_json(Object.new) }.to raise_error("Invalid JSON-RPC 2.0 Request")
      end
    end

    describe "from_hash" do
      it "creates a request from the hash" do
        request = JsonRpcRequest.new("puts","test",10)
        request.should == JsonRpcRequest.from_hash(request.as_json)
      end
    end
  end

  describe JsonRpcResponse do
    describe "as_json" do
      it "returns the json hash" do
        json = JsonRpcResponse.new(10).as_json
        json["jsonrpc"].should eql "2.0"
        json["id"].should eql 10
      end
    end

    describe "to_json" do
      it "returns the json string" do
        json = JsonRpcResponse.new(10).to_json.should be_a String
      end
    end

    describe "from_json" do
      it "creates a success response from the json string" do
        json = JsonRpcResponse.new(10).as_json
        json['result'] = "true"
        response = JsonRpcResponse.from_json(json.to_json)
        response.should be_a JsonRpcSuccessResponse
        response.result.should eql "true"
      end

      it "creates a error response from the json string" do
        json = JsonRpcResponse.new(10).as_json
        json['error'] = {"code"=>-1, "message"=>"error", "data"=>{"message"=>"problem"}}
        response = JsonRpcResponse.from_json(json.to_json)
        response.should be_a JsonRpcErrorResponse
        response.error.code.should eql -1
        response.error.message.should eql "error"
        response.error.data['message'].should eql "problem"
      end

      it "reports an error if there is no 'result' or 'error' key" do
        json = JsonRpcResponse.new(10).as_json
        expect { JsonRpcResponse.from_json(json.to_json) }.to raise_error("Invalid JSON-RPC 2.0 Response")
      end

      it "reports an error if the version isn't 2.0" do
        json = JsonRpcResponse.new(10).as_json
        json['jsonrpc'] = "1.1"
        json['result'] = "true"
        expect { JsonRpcResponse.from_json(json.to_json) }.to raise_error("Invalid JSON-RPC 2.0 Response")
      end

      it "reports an error if there is both a 'result' and 'error' key" do
        json = JsonRpcResponse.new(10).as_json
        json['result'] = "true"
        json['error'] = {"code"=>-1, "message"=>"error"}
        expect { JsonRpcResponse.from_json(json.to_json) }.to raise_error("Invalid JSON-RPC 2.0 Response")
      end

      it "reports an error if it is not json" do
        expect { JsonRpcResponse.from_json(Object.new) }.to raise_error("Invalid JSON-RPC 2.0 Response")
      end

      it "reports an error if the error hash is bad" do
        json = JsonRpcResponse.new(10).as_json
        json['error'] = {"code"=>-1}
        expect { JsonRpcResponse.from_json(json.to_json) }.to raise_error("Invalid JSON-RPC 2.0 Error")
      end
    end

  end
end

