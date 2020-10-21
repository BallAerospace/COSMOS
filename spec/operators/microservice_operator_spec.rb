# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'mock_redis'
require 'cosmos/operators/microservice_operator'

module Cosmos
  describe MicroserviceOperator do
    describe "initialize" do
      it "should call OperatorProcess.setup" do
        expect(OperatorProcess).to receive(:setup)
        op = MicroserviceOperator.new
      end

      it "should cycle every ENV['OPERATOR_CYCLE_TIME'] seconds" do
        ENV['OPERATOR_CYCLE_TIME'] = '60'
        op = MicroserviceOperator.new
        expect(op.cycle_time).to eq 60.0
      end
    end

    describe "update" do
      before(:each) do
        @redis = MockRedis.new
        allow(Redis).to receive(:new).and_return(@redis)
      end

      it "should query redis for new microservices and create OperatorProcesses" do
        config = { 'filename' => 'interface_microservice.rb', 'scope' => 'DEFAULT' }
        @redis.hset('cosmos_microservices', 'SCOPE__SERVICE__NAME', JSON.generate(config))

        # ENV['OPERATOR_CYCLE_TIME'] = '0.1'
        # thread = Thread.new { MicroserviceOperator.run }
        # sleep 0.2 # Allow to run

        op = MicroserviceOperator.new
        expect(op.processes).to be_empty()
        op.update()
        expect(op.processes.keys).to include('SCOPE__SERVICE__NAME')
        expect(op.processes['SCOPE__SERVICE__NAME']).to be_a OperatorProcess
        processes = op.processes.dup
        op.update()
        expect(op.processes).to eq processes # No change after update
      end

      # it "should restart changed microservices" do
      #   config = { filename: 'interface_microservice.rb', scope: 'DEFAULT' }
      #   JSON.generate(config)

      #   @redis.hset('cosmos_microservices', 'SCOPE__SERVICE__NAME', JSON.generate(config))

      #   op = MicroserviceOperator.new
      #   op.update()
      #   expect(op.processes.keys).to include('SCOPE__SERVICE__NAME')

      #   config = { filename: 'interface_microservice.rb', scope: 'DEFAULT', param: 'other' }
      #   @redis.hset('cosmos_microservices', 'SCOPE__SERVICE__NAME', JSON.generate(config))

      #   op.update()
      #   expect(op.processes).to be_empty()
      # end

      it "should remove deleted microservices" do
        config = { 'filename' => 'interface_microservice.rb', 'scope' => 'DEFAULT' }
        @redis.hset('cosmos_microservices', 'SCOPE__SERVICE__NAME', JSON.generate(config))

        op = MicroserviceOperator.new
        op.update()
        expect(op.processes.keys).to include('SCOPE__SERVICE__NAME')

        @redis.hdel('cosmos_microservices', 'SCOPE__SERVICE__NAME')

        op.update()
        expect(op.processes).to be_empty()
      end
    end
  end
end
