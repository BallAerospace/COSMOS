# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'spec_helper'
require 'openc3/topics/config_topic'

module OpenC3
  describe ConfigTopic do
    before(:each) do
      mock_redis()
    end

    describe "self.initialize_stream" do
      it "initializes the stream with the scope" do
        ConfigTopic.initialize_stream('DEFAULT')
        expect(EphemeralStore.scan_each(type: 'stream', count: 100).to_a).to include("DEFAULT__CONFIG")
      end
    end

    describe "self.write" do
      it "requires kind, type, name keys" do
        expect { ConfigTopic.write({ type: 'target', name: 'INST', plugin: 'PLUGIN'}, scope: 'DEFAULT') }.to raise_error(/ConfigTopic error/)
        expect { ConfigTopic.write({ kind: 'created', name: 'INST', plugin: 'PLUGIN'}, scope: 'DEFAULT') }.to raise_error(/ConfigTopic error/)
        expect { ConfigTopic.write({ kind: 'created', type: 'target', plugin: 'PLUGIN'}, scope: 'DEFAULT') }.to raise_error(/ConfigTopic error/)
      end

      it "requires kind to be 'created' or 'deleted'" do
        expect { ConfigTopic.write({ kind: 'unknown', type: 'target', name: 'INST', plugin: 'PLUGIN'}, scope: 'DEFAULT') }.to raise_error(/ConfigTopic error/)
      end
    end

    describe "self.read" do
      it "reads from an offset" do
        ConfigTopic.initialize_stream('DEFAULT')
        ConfigTopic.write({ kind: 'created', type: 'target', name: 'INST', plugin: 'PLUGIN'}, scope: 'DEFAULT')
        ConfigTopic.write({ kind: 'deleted', type: 'target', name: 'INST', plugin: 'PLUGIN'}, scope: 'DEFAULT')
        config = ConfigTopic.read(0, scope: 'DEFAULT') # read all
        expect(config[0][1]['kind']).to eql 'created'
        expect(config[0][1]['type']).to eql 'target'
        expect(config[0][1]['name']).to eql 'INST'
        expect(config[0][1]['plugin']).to eql 'PLUGIN'
        expect(config[1][1]['kind']).to eql 'deleted'
        expect(config[1][1]['type']).to eql 'target'
        expect(config[1][1]['name']).to eql 'INST'
        expect(config[1][1]['plugin']).to eql 'PLUGIN'
      end

      it "reads the latest" do
        ConfigTopic.initialize_stream('DEFAULT')
        ConfigTopic.write({ kind: 'created', type: 'target', name: 'INST', plugin: 'PLUGIN'}, scope: 'DEFAULT')
        ConfigTopic.write({ kind: 'deleted', type: 'target', name: 'INST', plugin: 'PLUGIN'}, scope: 'DEFAULT')
        config = ConfigTopic.read(scope: 'DEFAULT') # read latest
        expect(config[0][1]['kind']).to eql 'deleted'
        expect(config[0][1]['type']).to eql 'target'
        expect(config[0][1]['name']).to eql 'INST'
        expect(config[0][1]['plugin']).to eql 'PLUGIN'
      end
    end
  end
end
