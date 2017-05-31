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
    expect(Test1.new.as_json).to eql [:@test]
    expect(Test2.new.as_json).to eql Hash.new("test"=>0)
  end
end

describe Struct do
  it "implements as_json" do
    s = Struct.new(:test1, :test2)
    instance = s.new(1,2)
    hash = {"test1"=>1,"test2"=>2}
    expect(instance.as_json).to eql hash
  end
end

describe String do
  it "implements as_json" do
    expect("test".as_json).to eql "test"
    hash = {"json_class"=>"String","raw"=>[16]}
    expect("\x10".as_json).to eql hash
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
    expect(Test.new.as_json).to eql [1,2]
  end
end

describe Array do
  it "implements as_json" do
    expect([1,2,3].as_json).to eql [1,2,3]
  end
end

describe Hash do
  it "implements as_json" do
    hash = {"true"=>1,"false"=>0}
    expect(hash.as_json).to eql hash
  end
end

describe Time do
  it "implements as_json" do
    time = Time.new(2020,01,31,12,20,10)
    expect(time.as_json).to match "2020-01-31 12:20:10"
  end
end

describe Date do
  it "implements as_json" do
    date = Date.new(2020,01,31)
    expect(date.as_json).to eql "2020-01-31"
  end
end

describe DateTime do
  it "implements as_json" do
    dt = DateTime.new(2020,01,31,12,20,10)
    expect(dt.as_json).to match "2020-01-31T12:20:10"
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
    expect(json["class"]).to eql "TestError"
    expect(json["message"]).to eql "Error"
    hash = {"@test"=>"test"}
    expect(json["instance_variables"]).to eql hash
  end

  it "calls as_json from to_json" do
    expect(TestError.new("Error").to_json).to be_a String
  end

  it "creates an object from a hash" do
    json = TestError.new("Error").as_json
    error = Exception.from_hash(json)
    expect(error).to be_a TestError
    expect(error.message).to eql "Error"
  end

  it "rescues creating an object" do
    json = TestError.new("Error").as_json
    json["class"] = "ClassWhichDoesNotExist"
    json["message"] = "Error"
    json["backtrace"] = "trace"
    expect { Exception.from_hash(json) }.to raise_error(TypeError)
  end
end

module Cosmos

  describe JsonRpcRequest do
    describe "method" do
      it "returns the method" do
        expect(JsonRpcRequest.new("puts","test",10).method).to eql "puts"
      end
    end

    describe "params" do
      it "returns the parameters" do
        expect(JsonRpcRequest.new("puts",nil,10).params).to eql []
        expect(JsonRpcRequest.new("puts","test",10).params).to eql "test"
        expect(JsonRpcRequest.new("puts",["test",1],10).params).to eql ["test",1]
      end
    end

    describe "id" do
      it "returns the request id" do
        expect(JsonRpcRequest.new("puts",nil,10).id).to eql 10
      end
    end

    describe "as_json" do
      it "returns the json hash" do
        json = JsonRpcRequest.new("puts","test",10).as_json
        expect(json["jsonrpc"]).to eql "2.0"
        expect(json["method"]).to eql "puts"
        expect(json["params"]).to eql "test"
        expect(json["id"]).to eql 10
      end
    end

    describe "to_json" do
      it "returns the json string" do
        json = expect(JsonRpcRequest.new("puts","test",10).to_json).to be_a String
      end
    end

    describe "from_json" do
      it "creates a request from the json string" do
        request = JsonRpcRequest.new("puts","test",10)
        expect(request).to eq(JsonRpcRequest.from_json(request.to_json))
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
        expect(request).to eq(JsonRpcRequest.from_hash(request.as_json))
      end
    end
  end

  describe JsonRpcResponse do
    describe "as_json" do
      it "returns the json hash" do
        json = JsonRpcResponse.new(10).as_json
        expect(json["jsonrpc"]).to eql "2.0"
        expect(json["id"]).to eql 10
      end
    end

    describe "to_json" do
      it "returns the json string" do
        json = expect(JsonRpcResponse.new(10).to_json).to be_a String
      end
    end

    describe "from_json" do
      it "creates a success response from the json string" do
        json = JsonRpcResponse.new(10).as_json
        json['result'] = "true"
        response = JsonRpcResponse.from_json(json.to_json)
        expect(response).to be_a JsonRpcSuccessResponse
        expect(response.result).to eql "true"
      end

      it "creates a error response from the json string" do
        json = JsonRpcResponse.new(10).as_json
        json['error'] = {"code"=>-1, "message"=>"error", "data"=>{"message"=>"problem"}}
        response = JsonRpcResponse.from_json(json.to_json)
        expect(response).to be_a JsonRpcErrorResponse
        expect(response.error.code).to eql -1
        expect(response.error.message).to eql "error"
        expect(response.error.data['message']).to eql "problem"
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

