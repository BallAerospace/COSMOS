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
require 'openc3/models/note_model'

module OpenC3
  describe NoteModel do
    before(:each) do
      mock_redis()
    end

    def create_model(start: Time.now.to_i, stop: Time.now.to_i + 10,
      scope: 'DEFAULT', color: '#FF0000', description: '')
      model = NoteModel.new(
        scope: scope,
        start: start,
        stop: stop,
        color: color,
        description: description,
      )
      model.create()
      model
    end

    describe "self.pk" do
      it "returns the primary key" do
        expect(NoteModel.pk('DEFAULT')).to eql("DEFAULT__NOTE")
      end
    end

    describe "create" do
      it "raises error due to invalid start time" do
        expect { create_model(start: 'foo') }.to raise_error(SortedInputError)
        expect { create_model(start: 5.5) }.to raise_error(SortedInputError)
        expect { create_model(start: -1) }.to raise_error(SortedInputError)
      end

      it "raises error due to invalid stop time" do
        expect { create_model(stop: 'foo') }.to raise_error(SortedInputError)
        expect { create_model(stop: 5.5) }.to raise_error(SortedInputError)
        expect { create_model(stop: -1) }.to raise_error(SortedInputError)
      end

      it "allows future start times" do
        future = Time.now.to_i + 1000
        create_model(start: future, stop: future + 10)
      end

      it "creates default color for nil" do
        model = create_model(color: nil)
        expect(model.color).to_not be_nil
      end

      it "raises error due to start overlap" do
        now = Time.now.to_i
        create_model(start: now)
        expect { create_model(start: now) }.to raise_error(SortedOverlapError)
      end

      it "raises error due to stop < start" do
        now = Time.now.to_i
        expect { create_model(start: now, stop: now - 1) }.to raise_error(SortedInputError)
      end

      it "raises error due to invalid color" do
        expect { create_model(color: 'foo') }.to raise_error(SortedInputError)
      end
    end

    describe "update" do
      it "updates all the attributes" do
        now = Time.now.to_i
        model = create_model(start: now)
        expect(NoteModel.count(scope: 'DEFAULT')).to eql(1)
        model.update(start: now - 100, stop: now - 50, color: "#FFFFFF", description: "update")
        expect(NoteModel.count(scope: 'DEFAULT')).to eql(1)
        expect(model.start).to eql(now - 100)
        expect(model.stop).to eql(now - 50)
        expect(model.color).to eql('#FFFFFF')
        expect(model.description).to eql('update')

        hash = NoteModel.get(scope: 'DEFAULT', start: now - 100)
        # Test that the hash returned by get is updated
        expect(model.start).to eql(hash['start'])
        expect(model.stop).to eql(hash['stop'])
        expect(model.color).to eql(hash['color'])
        expect(model.description).to eql(hash['description'])
      end
    end

    describe "as_json" do
      it "encodes all the input parameters" do
        now = Time.now.to_i
        model = create_model(start: now, stop: now + 5, color: '#123456', description: 'json')
        json = model.as_json(:allow_nan => true)
        expect(json["start"]).to eql(now)
        expect(json["stop"]).to eql(now + 5)
        expect(json["color"]).to eql('#123456')
        expect(json['description']).to eql("json")
        expect(json['type']).to eql("note")
      end
    end

    describe "from_json" do
      it "encodes all the input parameters" do
        model = create_model()
        hash = model.as_json(:allow_nan => true)
        json = JSON.generate(hash)
        new_model = NoteModel.from_json(json, scope: 'DEFAULT')
        expect(new_model.start).to eql(hash['start'])
        expect(new_model.stop).to eql(hash['stop'])
        expect(new_model.color).to eql(hash['color'])
        expect(new_model.description).to eql(hash['description'])
      end
    end
  end
end
