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
    before(:all) do
      @redis = MockRedis.new
      @redis.instance_eval do
        def exists?(key)
          self.exists(key)
        end
      end
    end
    before(:each) do
      @redis.flushdb
      allow(Redis).to receive(:new).and_return(@redis)
    end

    describe 'instance' do
      it 'returns the same object' do
        expect(Store.instance).equal?(Store.instance)
      end
    end

    describe 'get_target' do
      it 'raises if TGT does not exist' do
        expect { Store.instance.get_target('TGT') }.to raise_error('Target TGT does not exist')
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
        expect { Store.instance.get_packet('TGT', 'PKT') }.to raise_error('Target TGT does not exist')
      end

      it 'raises if PKT does not exist' do
        Store.instance.hset('cosmostlm__TGT', 'X', Packet.new('TGT', 'PKT').as_json)
        expect { Store.instance.get_packet('TGT', 'PKT') }.to raise_error('Packet PKT does not exist')
      end

      it 'returns a packet hash' do
        Store.instance.hset('cosmostlm__TGT', 'PKT', JSON.generate(Packet.new('TGT', 'PKT').as_json))
        pkt = Store.instance.get_packet('TGT', 'PKT')
        expect(pkt).to be_a(Hash)
        expect(pkt['target_name']).to eql 'TGT'
        expect(pkt['packet_name']).to eql 'PKT'
      end
    end
  end
end
