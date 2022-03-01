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

    def generate_metadata(start:, target: 'FOO', scope: 'DEFAULT', metadata: nil)
      start_time = DateTime.now.new_offset(0) + (start / 24.0)
      metadata = {'cat' => 'dog', 'version' => 'v1'} if metadata.nil?
      MetadataModel.new(
        target: target,
        scope: scope,
        start: start_time.strftime("%s").to_i,
        color: '#FF0000',
        metadata: metadata,
      )
    end

    describe "self.X_current_value" do
      it "get the current metadata" do
        metadata = generate_metadata(start: -1.5)
        metadata.create()
        ret = MetadataModel.get_current_value(
          target: metadata.target,
          scope: 'DEFAULT'
        )
        expect(ret).not_to be_nil

        ret = MetadataModel.get_current_value(
          target: 'test',
          scope: 'DEFAULT'
        )
        expect(ret).to eql(nil)
      end
    end

    describe "self.get" do
      it "returns metadata between X and Y" do
        metadata = generate_metadata(start: -1.5)
        metadata.create()
        metadata = generate_metadata(start: -5.0)
        metadata.create()
        dt = DateTime.now.new_offset(0)
        start = (dt - (3 / 24.0)).strftime("%s").to_i
        stop = (dt - (1 / 24.0)).strftime("%s").to_i
        array = MetadataModel.get(scope: 'DEFAULT', start: start, stop: stop)
        expect(array.empty?).to eql(false)
        expect(array.length).to eql(1)
        expect(array[0]["start"]).not_to be_nil
      end
    end

    describe "self.all" do
      it "returns all entries" do
        metadata = generate_metadata(start: -2.0)
        metadata.create()
        metadata = generate_metadata(start: -4.0)
        metadata.create()
        all = MetadataModel.all(scope: 'DEFAULT')
        expect(all.empty?).to eql(false)
        expect(all.length).to eql(2)
        expect(all[0]["start"]).not_to be_nil
        expect(all[1]["start"]).not_to be_nil
      end
    end

    describe "self.score" do
      it "returns a MetadataModel at the start" do
        metadata = generate_metadata(start: -1.0)
        metadata.create()
        model = MetadataModel.score(score: metadata.start, scope: 'DEFAULT')
        expect(model["target"]).to eql(metadata.target)
        expect(model["start"]).to eql(metadata.start)
        expect(model["metadata"]).not_to be_nil
      end
    end

    describe "self.count" do
      it "returns the count/number of chronicles" do
        metadata = generate_metadata(start: -1.0)
        metadata.create()
        metadata = generate_metadata(start: -2.5)
        metadata.create()
        count = MetadataModel.count(scope: 'DEFAULT')
        expect(count).to eql(2)
      end
    end

    describe "self.destroy" do
      it "removes the score from the chronicle" do
        metadata = generate_metadata(start: -2.0)
        metadata.create()
        ret = MetadataModel.destroy(scope: 'DEFAULT', score: metadata.start)
        expect(ret).to eql(1)
        count = MetadataModel.count(scope: 'DEFAULT')
        expect(count).to eql(0)
      end
    end

    describe "self.range_destroy" do
      it "removes multiple members form of the timeline" do
        metadata = generate_metadata(start: -0.5)
        metadata.create()
        metadata = generate_metadata(start: -2.0)
        metadata.create()
        dt = DateTime.now.new_offset(0)
        min_score = (dt - (3.0 / 24.0)).strftime("%s").to_i
        max_score = (dt - (0.5 / 24.0)).strftime("%s").to_i
        ret = MetadataModel.range_destroy(
          scope: 'DEFAULT',
          min: min_score,
          max: max_score
        )
        expect(ret).to eql(2)
        count = MetadataModel.count(scope: 'DEFAULT')
        expect(count).to eql(0)
      end
    end

    describe "model.create" do
      it "raises error due to overlap starts inside A and ends inside A" do
        metadata = generate_metadata(start: -1.0)
        metadata.create()
        model = generate_metadata(start: -1.0)
        expect {
          model.create()
        }.to raise_error(MetadataOverlapError)
      end
    end

    describe "time parse" do
      it "raises error due to invalid time" do
        expect {
          MetadataModel.new(
            target: 'FOO',
            scope: 'DEFAULT',
            start: 'foo',
            color: '#00FF00',
            metadata: {'test' => 'fail'},
          )
        }.to raise_error(MetadataInputError)
      end
    end

    describe "color parse" do
      it "raises error due to invalid color" do
        expect {
          MetadataModel.new(
            target: 'FOO',
            scope: 'DEFAULT',
            start: Time.now.to_i,
            color: 'foo',
            metadata: {'test' => 'fail'},
          ).create()
        }.to raise_error(MetadataInputError)
      end
    end

    describe "model.update" do
      it "update metadata" do
        z_metadata = generate_metadata(start: -2.0)
        a_metadata = generate_metadata(start: -0.5)
        a_metadata.create()
        a_metadata.update(
          start: z_metadata.start,
          color: '#00AA00',
          metadata: {'bird' => 'update'}
        )
        expect(a_metadata.start).to eql(z_metadata.start)
        expect(a_metadata.color).to eql('#00AA00')
        expect(a_metadata.metadata).to include('bird')
      end
    end

    describe "update error" do
      it "raises error due to update is overlapping time point" do
        a_metadata = generate_metadata(start: -0.5)
        a_metadata.create()
        b_metadata = generate_metadata(start: -2.0)
        b_metadata.create()
        expect {
          a_metadata.update(
            start: b_metadata.start,
            color: "#00FF00",
            metadata: {'test' => 'bad_update'}
          )
        }.to raise_error(MetadataOverlapError)
      end
    end

    describe "notify" do
      it "update the top of a change to the timeline" do
        metadata = generate_metadata(start: -1.0)
        metadata.notify(kind: "new")
      end
    end

    describe "destroy" do
      it "the model to remove it" do
        metadata = generate_metadata(start: -1.0)
        metadata.create
        metadata.destroy
        metadata = MetadataModel.score(scope: 'DEFAULT', score: metadata.start)
        expect(metadata).to eql(nil)
      end
    end

    describe "as_json" do
      it "encodes all the input parameters" do
        name = "foobar"
        scope = "scope"
        metadata = generate_metadata(start: -1.0)
        json = metadata.as_json
        expect(json["target"]).to eql(metadata.target)
        expect(json["start"]).to eql(metadata.start)
        expect(json["metadata"]).not_to be_nil
      end
    end

    describe "from_json" do
      it "encodes all the input parameters" do
        metadata = generate_metadata(start: -1.0)
        model_hash = metadata.as_json
        json = JSON.generate(model_hash)
        new_metadata = MetadataModel.from_json(json, scope: 'DEFAULT')
        expect(metadata.start).to eql(new_metadata.start)
        expect(metadata.metadata).not_to be_nil
      end
    end
  end
end
