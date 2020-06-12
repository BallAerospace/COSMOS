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
require 'cosmos/packets/packet'
require 'cosmos/utilities/store'

module Cosmos
  describe Store do
    before(:each) do
      # Ensure the Store instance is cleared so we get a new mock each time
      Store.class_variable_set(:@@instance, nil)
      redis = MockRedis.new
      # TODO: Hack MockRedis to implement exists to return number of matches
      redis.instance_eval do
        def exists(key)
          db = self.instance_variable_get(:@db)
          db.keys.count(key)
        end
      end
      allow(Redis).to receive(:new).and_return(redis)
    end

    describe 'instance' do
      it 'returns the same object' do
        expect(Store.instance).equal?(Store.instance)
      end
    end

    describe 'get_target' do
      it 'raises if TGT does not exist' do
        expect { Store.instance.get_target('TGT') }.to raise_error("Target 'TGT' does not exist")
      end

      it 'returns a target hash' do
        Store.instance.hset('cosmos_targets', 'TGT', JSON.generate(Target.new('TGT').as_json))
        tgt = Store.instance.get_target('TGT')
        expect(tgt).to be_a(Hash)
        expect(tgt['name']).to eql 'TGT'
      end
    end

    describe 'get_packet' do
      it 'raises if TGT does not exist' do
        expect { Store.instance.get_packet('TGT', 'PKT') }.to raise_error("Target 'TGT' does not exist")
      end

      it 'raises if PKT does not exist' do
        Store.instance.hset('cosmostlm__TGT', 'X', JSON.generate(Packet.new('TGT', 'PKT').as_json))
        expect { Store.instance.get_packet('TGT', 'PKT') }.to raise_error("Packet 'PKT' does not exist")
      end

      it 'returns a packet hash' do
        Store.instance.hset('cosmostlm__TGT', 'PKT', JSON.generate(Packet.new('TGT', 'PKT').as_json))
        Store.instance.hset('cosmoscmd__TGT', 'PKT', JSON.generate(Packet.new('TGT1', 'PKT1').as_json))
        pkt = Store.instance.get_packet('TGT', 'PKT', type: 'tlm')
        expect(pkt).to be_a(Hash)
        expect(pkt['target_name']).to eql 'TGT'
        expect(pkt['packet_name']).to eql 'PKT'
        pkt = Store.instance.get_packet('TGT', 'PKT', type: 'cmd')
        expect(pkt).to be_a(Hash)
        expect(pkt['target_name']).to eql 'TGT1'
        expect(pkt['packet_name']).to eql 'PKT1'
      end
    end

    describe 'get_commands' do
      it 'raises if TGT does not exist' do
        expect { Store.instance.get_commands('TGT') }.to raise_error("Target 'TGT' does not exist")
      end

      it 'returns a command hash' do
        Store.instance.hset('cosmoscmd__TGT', 'PKT', JSON.generate(Packet.new('TGT', 'PKT').as_json))
        commands = Store.instance.get_commands('TGT')
        expect(commands).to be_a(Array)
        expect(commands[0]['target_name']).to eql('TGT')
        expect(commands[0]['packet_name']).to eql('PKT')
      end
    end

    describe 'get_telemetry' do
      it 'raises if TGT does not exist' do
        expect { Store.instance.get_telemetry('TGT') }.to raise_error("Target 'TGT' does not exist")
      end

      it 'returns a command hash' do
        Store.instance.hset('cosmostlm__TGT', 'PKT', JSON.generate(Packet.new('TGT', 'PKT').as_json))
        telemetry = Store.instance.get_telemetry('TGT')
        expect(telemetry).to be_a(Array)
        expect(telemetry[0]['target_name']).to eql('TGT')
        expect(telemetry[0]['packet_name']).to eql('PKT')
      end
    end
  end
end
