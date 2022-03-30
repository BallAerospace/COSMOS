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
    TGMO_GROUP = 'GROUP'.freeze

    def generate_trigger_group_model(
      name: TGMO_GROUP,
      color: '#ff0000'
    )
      return TriggerGroupModel.new(
        name: name,
        scope: $cosmos_scope,
        color: color
      )
    end

    before(:each) do
      mock_redis()
    end

    describe "self.all" do
      it "returns all trigger models" do
        generate_trigger_group_model().create()
        all = TriggerGroupModel.all(scope: $cosmos_scope)
        expect(all.empty?).to be_falsey()
        expect(all[TGMO_GROUP]['name']).to eql(TGMO_GROUP)
        expect(all[TGMO_GROUP]['scope']).to eql($cosmos_scope)
        expect(all[TGMO_GROUP]['color']).to eql('#ff0000')
        # scope seperation returns no trigger models
        all = TriggerGroupModel.all(scope: 'foobar')
        expect(all.empty?).to be_truthy()
      end
    end

    describe "self.names" do
      it "returns trigger names" do
        generate_trigger_group_model().create()
        all = TriggerGroupModel.names(scope: $cosmos_scope)
        expect(all.empty?).to be_falsey()
        expect(all[0]).to eql(TGMO_GROUP)
      end
    end

    describe "self.get" do
      it "returns a single trigger model" do
        generate_trigger_group_model().create()
        foobar = TriggerGroupModel.get(name: TGMO_GROUP, scope: $cosmos_scope)
        expect(foobar.name).to eql(TGMO_GROUP)
        expect(foobar.scope).to eql($cosmos_scope)
        expect(foobar.color).to_not be_nil()
      end
    end

    describe "self.delete" do
      it "delete a trigger" do
        generate_trigger_group_model().create()
        TriggerGroupModel.delete(name: TGMO_GROUP, scope: $cosmos_scope)
        all = TriggerGroupModel.all(scope: $cosmos_scope)
        expect(all.empty?).to be_truthy()
      end
    end

    describe "instance attr_reader" do
      it "Cosmos::TriggerModel" do
        model = generate_trigger_group_model()
        expect(model.name).to eql(TGMO_GROUP)
        expect(model.scope).to eql($cosmos_scope)
        expect(model.color).to_not be_nil()
      end
    end

    describe "instance destory" do
      it "remove an instance of a trigger" do
        generate_trigger_group_model().create()
        model = TriggerGroupModel.get(name: TGMO_GROUP, scope: $cosmos_scope)
        model.destroy()
        all = TriggerGroupModel.all(scope: $cosmos_scope)
        expect(all.empty?).to be_truthy()
      end
    end

    describe "instance as_json" do
      it "encodes all the input parameters" do
        json = generate_trigger_group_model().as_json
        expect(json['name']).to eql(TGMO_GROUP)
        expect(json['scope']).to eql($cosmos_scope)
        expect(json['color']).to eql('#ff0000')
      end
    end
  end
end
