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
require 'openc3/models/reaction_model'
require 'openc3/models/trigger_group_model'
require 'openc3/models/trigger_model'

module OpenC3
  describe ReactionModel do
    RMO_GROUP = 'GROUP'

    def generate_trigger_group_model(
      name: RMO_GROUP,
      color: '#ff0000'
    )
      return TriggerGroupModel.new(
        name: name,
        scope: $openc3_scope,
        color: color
      )
    end

    def generate_custom_trigger(
      name: 'foobar',
      left: {'type' => 'float', 'float' => '9000'},
      operator: '>',
      right: {'type' => 'float', 'float' => '42'}
    )
      return TriggerModel.new(
        name: name,
        scope: $openc3_scope,
        group: RMO_GROUP,
        left: left,
        operator: operator,
        right: right,
        dependents: []
      )
    end

    def generate_custom_reaction(
      name: 'foobar',
      description: 'another test',
      triggers: [{'name' => 'foobar', 'group' => RMO_GROUP}],
      actions: [{'type' => 'command', 'value' => 'TEST'}]
    )
      return ReactionModel.new(
        name: name,
        scope: $openc3_scope,
        description: description,
        snooze: 300,
        triggers: triggers,
        actions: actions
      )
    end

    def generate_reaction
      generate_custom_trigger().create()
      reaction = generate_custom_reaction()
      reaction.create()
      return reaction
    end

    before(:each) do
      mock_redis()
      generate_trigger_group_model().create()
    end

    describe "check attr_reader" do
      it "OpenC3::ReactionModel" do
        model = generate_reaction()
        expect(model.name).to eql('foobar')
        expect(model.scope).to eql($openc3_scope)
        expect(model.description).to eql('another test')
        expect(model.active).to be_truthy()
        expect(model.snooze).to eql(300)
        expect(model.snoozed_until).to be_nil()
        expect(model.triggers.empty?).to be_falsey()
        expect(model.actions.empty?).to be_falsey()
      end
    end

    describe "self.all" do
      it "scope seperation returns no trigger models" do
        generate_reaction()
        all = ReactionModel.all(scope: 'foobar')
        expect(all.empty?).to be_truthy()
      end
    end

    describe "self.all" do
      it "returns all the reactions" do
        generate_reaction()
        all = ReactionModel.all(scope: $openc3_scope)
        expect(all.empty?).to be_falsey()
        expect(all['foobar'].empty?).to be_falsey()
        expect(all['foobar']['name']).to eql('foobar')
        expect(all['foobar']['scope']).to eql($openc3_scope)
        expect(all['foobar']['triggers']).to_not be_nil()
        expect(all['foobar']['actions']).to_not be_nil()
      end
    end

    describe "self.names" do
      it "returns reaction names" do
        generate_reaction()
        all = ReactionModel.names(scope: $openc3_scope)
        expect(all.empty?).to be_falsey()
        expect(all[0]).to eql('foobar')
      end
    end

    describe "self.get" do
      it "returns a single reaction model" do
        generate_reaction()
        foobar = ReactionModel.get(name: 'foobar', scope: $openc3_scope)
        expect(foobar.name).to eql('foobar')
        expect(foobar.scope).to eql($openc3_scope)
        expect(foobar.description).to eql('another test')
        expect(foobar.triggers.empty?).to be_falsey()
        expect(foobar.actions.empty?).to be_falsey()
      end
    end

    describe "single reaction test" do
      it "delete an reaction" do
        generate_reaction()
        ReactionModel.delete(name: 'foobar', scope: $openc3_scope)
        all = ReactionModel.all(scope: $openc3_scope)
        expect(all.empty?).to be_truthy()
        trigger = TriggerModel.get(name: 'foobar', group: RMO_GROUP, scope: $openc3_scope)
        expect(trigger.dependents.empty?).to be_truthy()
      end
    end

    describe "as_json" do
      it "encodes all the input parameters" do
        model = generate_reaction()
        json = model.as_json(:allow_nan => true)
        expect(json['name']).to eql('foobar')
        expect(json['scope']).to eql($openc3_scope)
        expect(json['description']).to eql('another test')
        expect(json['snooze']).to eql(300)
        expect(json['triggers']).to_not be_nil()
        expect(json['actions']).to_not be_nil()
      end
    end

    describe "single reaction test" do
      it "create an reaction that references an invalid triggers" do
        expect {
          generate_custom_reaction(
            triggers: ['bad-trigger'],
          ).create()
        }.to raise_error(ReactionInputError)
        expect {
          generate_custom_reaction(
            triggers: [{'name' => 'bad-trigger', 'group' => RMO_GROUP}],
          ).create()
        }.to raise_error(ReactionInputError)
      end
    end

    describe "single reaction test" do
      it "create an reaction that uses a bad actions" do
        expect {
          generate_custom_reaction(
            actions: [{'type' => 'meow', 'data' => 'TEST'}]
          ).create()
        }.to raise_error(ReactionInputError)
        expect {
          generate_custom_reaction(
            actions: [{'type' => 'command'}]
          ).create()
        }.to raise_error(ReactionInputError)
      end
    end

  end
end
