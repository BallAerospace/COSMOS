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

    def create_model(start: Time.now.to_i, scope: 'DEFAULT', color: '#FF0000',
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

    describe "create" do
      it "raises error due to invalid start" do
        expect { create_model(start: 'foo') }.to raise_error(SortedInputError)
        expect { create_model(start: 5.5) }.to raise_error(SortedInputError)
        expect { create_model(start: -1) }.to raise_error(SortedInputError)
      end

      it "allows future start times" do
        future = Time.now.to_i + 1000
        create_model(start: future)
      end

      it "raises error due to start overlap" do
        now = Time.now.to_i
        create_model(start: now)
        expect { create_model(start: now) }.to raise_error(SortedOverlapError)
      end

      it "raises error due to invalid color" do
        expect { create_model(color: 'foo') }.to raise_error(SortedInputError)
      end

      it "creates default color for nil" do
        model = create_model(color: nil)
        expect(model.color).to_not be_nil
      end

      it "raises error due to invalid metadata" do
        expect { create_model(metadata: nil) }.to raise_error(SortedInputError)
        expect { create_model(metadata: 'foo') }.to raise_error(SortedInputError)
        expect { create_model(metadata: ['one', 'two']) }.to raise_error(SortedInputError)
      end
    end

    describe "update" do
      it "updates metadata" do
        now = Time.now.to_i
        model = create_model(start: now)
        model.update(
          start: now,
          color: '#00AA00',
          metadata: {'bird' => 'update'}
        )
        expect(model.start).to eql(now)
        expect(model.color).to eql('#00AA00')
        expect(model.metadata).to eql({'bird' => 'update'})

        hash = MetadataModel.get(scope: 'DEFAULT', start: now)
        # Test that the hash returned by get is updated
        expect(model.start).to eql(hash['start'])
        expect(model.color).to eql(hash['color'])
        expect(model.metadata).to eql(hash['metadata'])
      end
    end

    describe "as_json" do
      it "encodes all the input parameters" do
        now = Time.now.to_i
        model = create_model(start: now, color: '#123456', metadata: {'test' => 'one', 'foo' => 'bar'})
        json = model.as_json
        expect(json["start"]).to eql(now)
        expect(json["color"]).to eql('#123456')
        expect(json["metadata"]).to eql({'test' => 'one', 'foo' => 'bar'})
        expect(json['type']).to eql("metadata")
      end
    end

    describe "from_json" do
      it "encodes all the input parameters" do
        model = create_model()
        hash = model.as_json
        json = JSON.generate(hash)
        new_model = MetadataModel.from_json(json, scope: 'DEFAULT')
        expect(new_model).to be_a MetadataModel
        expect(new_model.start).to eql(hash['start'])
        expect(new_model.color).to eql(hash['color'])
        expect(new_model.metadata).to eql(hash['metadata'])
      end
    end
  end
end
