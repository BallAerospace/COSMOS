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
require 'openc3/models/metadata_model'

module OpenC3

  describe MetadataModel do
    before(:each) do
      mock_redis()
    end

    def create_model(start: Time.now.to_i, scope: 'DEFAULT', color: '#FF0000',
      metadata: {'cat' => 'dog', 'version' => 'v1'}, constraints: nil)
      model = MetadataModel.new(
        scope: scope,
        start: start,
        color: color,
        metadata: metadata,
        constraints: constraints,
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

      it "validates metadata with constraints" do
        now = Time.now.to_i
        # Verify we can create and validate with mix and match key strings vs symbols
        create_model(start: now, metadata: {'key' => 1}, constraints: {'key' => (1..4)})
        create_model(start: now + 1, metadata: {'key' => 1}, constraints: {key: (1..4)})
        create_model(start: now + 2, metadata: {key: 1}, constraints: {'key' => (1..4)})
        create_model(start: now + 3, metadata: {key: 1}, constraints: {key: (1..4)})
        expect { create_model(start: now + 5, metadata: {key: 0}, constraints: {key: (1..4)}) }.to raise_error(SortedInputError, /Constraint violation/)
        create_model(start: now + 10, metadata: {key: 'one'}, constraints: {key: ['one', 'two']})
        expect { create_model(start: now + 15, metadata: {key: 'other'}, constraints: {key: ['one', 'two']}) }.to raise_error(SortedInputError, /Constraint violation/)
      end

      it "raises error due to invalid constraints" do
        expect { create_model(constraints: 'foo') }.to raise_error(SortedInputError)
        expect { create_model(constraints: ['one', 'two']) }.to raise_error(SortedInputError)
        expect { create_model(constraints: {'key': ['one', 'two']}) }.to raise_error(SortedInputError)
      end
    end

    describe "update" do
      it "updates start and color" do
        now = Time.now.to_i
        model = create_model(start: now, metadata: {val: 1})
        expect(MetadataModel.count(scope: 'DEFAULT')).to eql(1)
        model.update(start: now + 100, color: '#00AA00')
        expect(MetadataModel.count(scope: 'DEFAULT')).to eql(1)
        expect(model.start).to eql(now + 100)
        expect(model.color).to eql('#00AA00')
        expect(model.metadata).to eql({'val' => 1})

        hash = MetadataModel.get(scope: 'DEFAULT', start: now + 100)
        # Test that the hash returned by get is updated
        expect(model.start).to eql(hash['start'])
        expect(model.color).to eql(hash['color'])
        expect(model.metadata).to eql(hash['metadata'])
      end

      it "updates metadata and constraints" do
        now = Time.now.to_i
        model = create_model(start: now, metadata: {val: 1}, constraints: {val: [1,2,3]})
        expect(MetadataModel.count(scope: 'DEFAULT')).to eql(1)
        model.update(metadata: {val: 4}, constraints: {val: (1..5)})
        expect(MetadataModel.count(scope: 'DEFAULT')).to eql(1)
        expect(model.start).to eql(now)
        expect(model.metadata).to eql({'val' => 4})
        expect(model.constraints).to eql({'val' => 1..5})

        hash = MetadataModel.get(scope: 'DEFAULT', start: now)
        # Test that the hash returned by get is updated
        expect(model.start).to eql(hash['start'])
        expect(model.color).to eql(hash['color'])
        expect(model.metadata).to eql(hash['metadata'])
        expect({'val' => '1..5'}).to eql(hash['constraints'])
      end

      it "rejects update if constraints violated" do
        now = Time.now.to_i
        model = create_model(start: now, metadata: {val: 1}, constraints: {val: [1,2,3]})
        expect { model.update(metadata: {val: 4}) }.to raise_error(SortedInputError, /Constraint violation/)
        hash = MetadataModel.get(scope: 'DEFAULT', start: now)
        # Test that the hash returned by get is NOT updated
        expect(model.start).to eql(hash['start'])
        expect(model.color).to eql(hash['color'])
        expect({'val' => 1}).to eql(hash['metadata'])
      end
    end

    describe "as_json, to_s" do
      it "encodes all the input parameters" do
        now = Time.now.to_i
        model = create_model(start: now, color: '#123456', metadata: {'test' => 'one', 'foo' => 'bar'})
        json = model.as_json(:allow_nan => true)
        expect(json).to eql(model.to_s)
        expect(json["start"]).to eql(now)
        expect(json["color"]).to eql('#123456')
        expect(json["metadata"]).to eql({'test' => 'one', 'foo' => 'bar'})
        expect(json['type']).to eql("metadata")
      end
    end

    describe "from_json" do
      it "encodes all the input parameters" do
        model = create_model()
        hash = model.as_json(:allow_nan => true)
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
