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
require 'cosmos/models/trigger_group_model'
require 'cosmos/models/trigger_model'

module Cosmos
  describe TriggerGroupModel do
    SCOPE = 'DEFAULT'.freeze
    GROUP = 'GROUP'.freeze

    def generate_trigger_group_model(
      name: GROUP,
      color: '#ff0000'
    )
      return TriggerGroupModel.new(
        name: name,
        scope: SCOPE,
        color: color
      )
    end

    before(:each) do
      mock_redis()
    end

    describe "self.all" do
      it "returns all trigger models" do
        generate_trigger_group_model().create()
        all = TriggerGroupModel.all(scope: SCOPE)
        expect(all.empty?).to be_falsey()
        expect(all[GROUP]['name']).to eql(GROUP)
        expect(all[GROUP]['scope']).to eql(SCOPE)
        expect(all[GROUP]['color']).to eql('#ff0000')
        # scope seperation returns no trigger models
        all = TriggerGroupModel.all(scope: 'foobar')
        expect(all.empty?).to be_truthy()
      end
    end

    describe "self.names" do
      it "returns trigger names" do
        generate_trigger_group_model().create()
        all = TriggerGroupModel.names(scope: SCOPE)
        expect(all.empty?).to be_falsey()
        expect(all[0]).to eql(GROUP)
      end
    end

    describe "self.get" do
      it "returns a single trigger model" do
        generate_trigger_group_model().create()
        foobar = TriggerGroupModel.get(name: GROUP, scope: SCOPE)
        expect(foobar.name).to eql(GROUP)
        expect(foobar.scope).to eql(SCOPE)
        expect(foobar.color).to_not be_nil()
      end
    end

    describe "self.delete" do
      it "delete a trigger" do
        generate_trigger_group_model().create()
        TriggerGroupModel.delete(name: GROUP, scope: SCOPE)
        all = TriggerGroupModel.all(scope: SCOPE)
        expect(all.empty?).to be_truthy()
      end
    end

    describe "instance attr_reader" do
      it "Cosmos::TriggerModel" do
        model = generate_trigger_group_model()
        expect(model.name).to eql(GROUP)
        expect(model.scope).to eql(SCOPE)
        expect(model.color).to_not be_nil()
      end
    end

    describe "instance destory" do
      it "remove an instance of a trigger" do
        generate_trigger_group_model().create()
        model = TriggerGroupModel.get(name: GROUP, scope: SCOPE)
        model.destroy()
        all = TriggerGroupModel.all(scope: SCOPE)
        expect(all.empty?).to be_truthy()
      end
    end

    describe "instance as_json" do
      it "encodes all the input parameters" do
        json = generate_trigger_group_model().as_json
        expect(json['name']).to eql(GROUP)
        expect(json['scope']).to eql(SCOPE)
        expect(json['color']).to eql('#ff0000')
      end
    end
  end
end
