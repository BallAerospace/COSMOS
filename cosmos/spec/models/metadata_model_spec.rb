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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'spec_helper'
require 'cosmos/models/metadata_model'

module Cosmos

  describe MetadataModel do
    before(:each) do
      mock_redis()
    end

    def create_metadata(start: Time.now.to_i, scope: 'DEFAULT', color: '#FF0000',
      metadata: {'cat' => 'dog', 'version' => 'v1'})
      model = MetadataModel.new(
        scope: scope,
        start: start,
        color: color,
        metadata: metadata,
      )
      model.create()
      model
    end

    describe "self.pk" do
      it "returns the primary key" do
        expect(MetadataModel.pk('DEFAULT')).to eql("DEFAULT__METADATA")
      end
    end

    describe "self.get_current_value" do
      it "get the current metadata" do
        now = Time.now.to_i
        create_metadata(color: '#FFFFFF', start: now)
        create_metadata(start: now - 10)
        create_metadata(start: now - 20)
        json = MetadataModel.get_current_value(
          scope: 'DEFAULT'
        )
        hash = JSON.parse(json)
        expect(hash['start']).to eql(now)
        expect(hash['color']).to eql('#FFFFFF')
      end
    end

    describe "self.get" do
      it "returns metadata" do
        now = Time.now.to_i
        create_metadata(start: now)
        create_metadata(color: '#FFFFFF', start: now - 10)
        create_metadata(start: now - 20)
        hash = MetadataModel.get(scope: 'DEFAULT', start: now - 10)
        expect(hash["start"]).to eql(now - 10)
        expect(hash['color']).to eql('#FFFFFF')
      end
    end

    describe "self.all" do
      it "returns all entries" do
        now = Time.now.to_i
        create_metadata(start: now)
        create_metadata(start: now - 10)
        create_metadata(start: now - 20)
        all = MetadataModel.all(scope: 'DEFAULT')
        # Returned in order from oldest to newest
        expect(all[0]["start"]).to eql(now - 20)
        expect(all[1]["start"]).to eql(now - 10)
        expect(all[2]["start"]).to eql(now)
      end
    end

    describe "self.count" do
      it "returns the count of metadata" do
        now = Time.now.to_i
        expect(MetadataModel.count(scope: 'DEFAULT')).to eql(0)
        create_metadata(start: now)
        expect(MetadataModel.count(scope: 'DEFAULT')).to eql(1)
        create_metadata(start: now - 10)
        expect(MetadataModel.count(scope: 'DEFAULT')).to eql(2)
        create_metadata(start: now - 20)
        expect(MetadataModel.count(scope: 'DEFAULT')).to eql(3)
      end
    end

    describe "self.destroy" do
      it "removes the metadata" do
        now = Time.now.to_i
        create_metadata(start: now)
        create_metadata(start: now - 10)
        create_metadata(start: now - 20)
        ret = MetadataModel.destroy(scope: 'DEFAULT', start: now - 10)
        expect(ret).to eql(1)
        expect(MetadataModel.count(scope: 'DEFAULT')).to eql(2)
        all = MetadataModel.all(scope: 'DEFAULT')
        expect(all[0]["start"]).to eql(now - 20)
        expect(all[1]["start"]).to eql(now)
      end
    end

    describe "self.range_destroy" do
      it "removes multiple metadata entries" do
        now = Time.now.to_i
        create_metadata(start: now)
        create_metadata(start: now - 10)
        create_metadata(start: now - 20)
        ret = MetadataModel.range_destroy(
          scope: 'DEFAULT',
          start: now - 10,
          stop: now
        )
        expect(ret).to eql(2)
        expect(MetadataModel.count(scope: 'DEFAULT')).to eql(1)
        all = MetadataModel.all(scope: 'DEFAULT')
        expect(all[0]["start"]).to eql(now - 20)
      end
    end

    describe "initialize" do
      it "raises error due to invalid time" do
        expect { create_metadata(start: 'foo') }.to raise_error(MetadataInputError)
        expect { create_metadata(start: 5.5) }.to raise_error(MetadataInputError)
        expect { create_metadata(start: -1) }.to raise_error(MetadataInputError)
      end

      it "allows future times" do
        future = Time.now.to_i + 1000
        create_metadata(start: future)
      end

      it "raises error due to start overlap" do
        now = Time.now.to_i
        create_metadata(start: now)
        expect { create_metadata(start: now) }.to raise_error(MetadataOverlapError)
      end

      it "raises error due to invalid color" do
        expect { create_metadata(color: 'foo') }.to raise_error(MetadataInputError)
      end

      it "raises error due to invalid metadata" do
        expect { create_metadata(metadata: nil) }.to raise_error(MetadataInputError)
        expect { create_metadata(metadata: 'foo') }.to raise_error(MetadataInputError)
        expect { create_metadata(metadata: ['one', 'two']) }.to raise_error(MetadataInputError)
      end
    end

    describe "update" do
      it "updates metadata" do
        now = Time.now.to_i
        model = create_metadata(start: now)
        model.update(
          start: now,
          color: '#00AA00',
          metadata: {'bird' => 'update'}
        )
        hash = MetadataModel.get(scope: 'DEFAULT', start: now)
        expect(hash['start']).to eql(now)
        expect(hash['color']).to eql('#00AA00')
        expect(hash['metadata']).to eql({'bird' => 'update'})
      end
    end

    describe "destroy" do
      it "removes the metadata" do
        metadata = create_metadata()
        expect(MetadataModel.count(scope: 'DEFAULT')).to eql(1)
        metadata.destroy
        expect(MetadataModel.count(scope: 'DEFAULT')).to eql(0)
      end
    end

    describe "as_json" do
      it "encodes all the input parameters" do
        now = Time.now.to_i
        metadata = create_metadata(start: now, color: '#123456', metadata: {'test' => 'one', 'foo' => 'bar'})
        json = metadata.as_json
        expect(json["start"]).to eql(now)
        expect(json["color"]).to eql('#123456')
        expect(json["color"]).to eql('#123456')
        expect(json["metadata"]).to eql({'test' => 'one', 'foo' => 'bar'})
        expect(json['type']).to eql("metadata")
      end
    end

    describe "from_json" do
      it "encodes all the input parameters" do
        metadata = create_metadata()
        hash = metadata.as_json
        json = JSON.generate(hash)
        # We have to delete the existing first to allow the new one to be created
        metadata.destroy
        new_metadata = MetadataModel.from_json(json, scope: 'DEFAULT')
        expect(metadata.start).to eql(hash['start'])
        expect(metadata.metadata).to eql(hash['metadata'])
      end
    end
  end
end
