# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
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
  describe TriggerModel do
    SCOPE = 'DEFAULT'.freeze
    GROUP = 'ALPHA'.freeze

    def generate_trigger(
      name: 'foobar',
      left: {'type' => 'float', 'float' => '9000'},
      operator: '>',
      right: {'type' => 'float', 'float' => '42'},
      group: GROUP
    )
      return TriggerModel.new(
        name: name,
        scope: SCOPE,
        group: group,
        left: left,
        operator: operator,
        right: right,
        dependents: []
      )
    end

    def generate_trigger_dependent_model
      generate_trigger(name: 'left').create()
      generate_trigger(name: 'right').create()
      foobar = generate_trigger(
        name: 'foobar',
        left: {'type' => 'trigger', 'trigger' => 'left'},
        operator: 'AND',
        right: {'type' => 'trigger', 'trigger' => 'right'}
      )
      foobar.create()
      return foobar
    end

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
      generate_trigger_group_model().create()
    end

    describe "self.all" do
      it "returns all trigger models" do
        generate_trigger().create()
        all = TriggerModel.all(group: GROUP, scope: SCOPE)
        expect(all.empty?).to be_falsey()
        expect(all['foobar'].empty?).to be_falsey()
        expect(all['foobar']['scope']).to eql(SCOPE)
        expect(all['foobar']['name']).to eql('foobar')
        expect(all['foobar']['group']).to eql(GROUP)
        expect(all['foobar']['left']).to_not be_nil()
        expect(all['foobar']['state']).to be_falsey()
        expect(all['foobar']['active']).to be_truthy()
        expect(all['foobar']['operator']).to eql('>')
        expect(all['foobar']['right']).to_not be_nil()
        expect(all['foobar']['dependents']).to be_truthy()
        # scope seperation returns no trigger models
        all = TriggerModel.all(group: GROUP, scope: 'foobar')
        expect(all.empty?).to be_truthy()
      end
    end

    describe "self.names" do
      it "returns trigger names" do
        generate_trigger().create()
        all = TriggerModel.names(scope: SCOPE, group: GROUP)
        expect(all.empty?).to be_falsey()
        expect(all[0]).to eql('foobar')
      end
    end

    describe "self.get" do
      it "returns a single trigger model" do
        generate_trigger().create()
        foobar = TriggerModel.get(name: 'foobar', scope: SCOPE, group: GROUP)
        expect(foobar.name).to eql('foobar')
        expect(foobar.scope).to eql(SCOPE)
        expect(foobar.group).to eql(GROUP)
        expect(foobar.left).to have_key('float')
        expect(foobar.operator).to eql('>')
        expect(foobar.right).to have_key('type')
        expect(foobar.active).to be_truthy()
        expect(foobar.state).to be_falsey()
        expect(foobar.dependents.empty?).to be_truthy()
        expect(foobar.roots.empty?).to be_truthy()
      end
    end

    describe "self.delete" do
      it "delete a trigger" do
        generate_trigger().create()
        TriggerModel.delete(name: 'foobar', scope: SCOPE, group: GROUP)
        all = TriggerModel.all(group: GROUP, scope: SCOPE)
        expect(all.empty?).to be_truthy()
      end
    end

    describe "instance attr_reader" do
      it "Cosmos::TriggerModel" do
        model = generate_trigger()
        expect(model.name).to eql('foobar')
        expect(model.scope).to eql(SCOPE)
        expect(model.group).to eql(GROUP)
        expect(model.left).to have_key('float')
        expect(model.operator).to eql('>')
        expect(model.right).to have_key('type')
        expect(model.active).to be_truthy()
        expect(model.state).to be_falsey()
        expect(model.dependents.empty?).to be_truthy()
        expect(model.roots).to_not be_nil()
      end
    end

    describe "instance destory" do
      it "remove an instance of a trigger" do
        generate_trigger().create()
        model = TriggerModel.get(name: 'foobar', scope: SCOPE, group: GROUP)
        model.destroy()
        all = TriggerModel.all(group: GROUP, scope: SCOPE)
        expect(all.empty?).to be_truthy()
      end
    end

    describe "instance active methods" do
      it "deactivate and then activate trigger" do
        model = generate_trigger()
        model.deactivate()
        expect(model.active).to be_falsey()
        model.activate()
        expect(model.active).to be_truthy()
      end
    end

    describe "instance state methods" do
      it "disable and then enable trigger" do
        model = generate_trigger()
        model.create()
        model.disable()
        expect(model.state).to be_falsey()
        model.enable()
        expect(model.state).to be_truthy()
      end
    end

    describe "instance as_json" do
      it "encodes all the input parameters" do
        json = generate_trigger().as_json
        expect(json['name']).to eql('foobar')
        expect(json['scope']).to eql(SCOPE)
        expect(json['active']).to be_truthy()
        expect(json['state']).to be_falsey()
        expect(json['group']).to eql(GROUP)
        expect(json['left']).to_not be_nil()
        expect(json['operator']).to eql('>')
        expect(json['right']).to_not be_nil()
        expect(json['dependents']).to_not be_nil()
      end
    end

    describe "trigger test" do
      it "create a trigger that references an invalid trigger" do
        expect {
          generate_trigger(
            left: {'type' => 'trigger', 'trigger' => 'foo'},
            operator: 'AND',
            right: {'type' => 'trigger', 'trigger' => 'bar'}
          ).create()
        }.to raise_error(TriggerError)
      end
    end

    describe "trigger test" do
      it "create a trigger that references an invalid type" do
        expect {
          generate_trigger(
            left: {'type' => 'right', 'trigger' => 'foo'},
            operator: 'AND',
            right: {'type' => 'meow', 'trigger' => 'bar'}
          )
        }.to raise_error(TriggerError)
      end
    end

    describe "dependent trigger test" do
      it "create a trigger that has incorrect operator" do
        generate_trigger_dependent_model()
        expect {
          generate_trigger(
            left: {'type' => 'trigger', 'trigger' => 'left'},
            operator: '<',
            right: {'type' => 'trigger', 'trigger' => 'right'}
          )
        }.to raise_error(TriggerError)
      end
    end

    describe "dependent trigger test" do
      it "create a trigger that has an invalid operator" do
        generate_trigger_dependent_model()
        expect {
          generate_trigger(
            left: {'type' => 'trigger', 'trigger' => 'left'},
            operator: 'MEOW',
            right: {'type' => 'trigger', 'trigger' => 'right'}
          )
        }.to raise_error(TriggerError)
      end
    end

    describe "dependent trigger test" do
      it "create a trigger that has an invalid type less than match" do
        generate_trigger_dependent_model()
        expect {
          generate_trigger(
            left: {'type' => 'trigger', 'trigger' => 'left'},
            operator: '<',
            right: {'type' => 'value', 'value' => '42'}
          )
        }.to raise_error(TriggerError)
      end
    end

    describe "dependent trigger test" do
      it "create a trigger that has an invalid type and match" do
        generate_trigger_dependent_model()
        expect {
          generate_trigger(
            left: {'type' => 'trigger', 'trigger' => 'left'},
            operator: 'AND',
            right: {'type' => 'value', 'value' => '42'}
          )
        }.to raise_error(TriggerError)
      end
    end

    describe "dependent trigger test" do
      it "create a trigger that tries to use a different group" do
        generate_trigger_dependent_model()
        expect {
          generate_trigger(
            name: 'fooGroup',
            left: {'type' => 'trigger', 'trigger' => 'left'},
            right: {'type' => 'trigger', 'trigger' => 'right'},
            group: 'FOOBAR'
          ).create()
        }.to raise_error(TriggerError)
      end
    end

    describe "dependent trigger test" do
      it "create a trigger that references another trigger" do
        foobar = generate_trigger_dependent_model()
        expect(foobar.roots.empty?).to be_falsey()
        left = TriggerModel.get(name: 'left', group: GROUP, scope: SCOPE)
        expect(left.dependents.empty?).to be_falsey()
        right = TriggerModel.get(name: 'right', group: GROUP, scope: SCOPE)
        expect(right.dependents.empty?).to be_falsey()
      end
    end

    describe "dependent trigger test" do
      it "delete a trigger that references another trigger" do
        generate_trigger_dependent_model()
        expect {
          TriggerModel.delete(name: 'left', group: GROUP, scope: SCOPE)
        }.to raise_error(TriggerError)
        all = TriggerModel.all(group: GROUP, scope: SCOPE)
        expect(all.size).to eql(3)
        expect(all.empty?).to be_falsey()
      end
    end

    describe "dependent trigger test" do
      it "delete a trigger" do
        generate_trigger_dependent_model()
        TriggerModel.delete(name: 'foobar', group: GROUP, scope: SCOPE)
        TriggerModel.delete(name: 'left', group: GROUP, scope: SCOPE)
        TriggerModel.delete(name: 'right', group: GROUP, scope: SCOPE)
        all = TriggerModel.all(group: GROUP, scope: SCOPE)
        expect(all.empty?).to be_truthy()
      end
    end

    describe "dependent trigger test" do
      it "make OR trigger" do
        generate_trigger_dependent_model()
        model = generate_trigger(
          name: 'orTest',
          left: {'type' => 'trigger', 'trigger' => 'left'},
          operator: 'OR',
          right: {'type' => 'trigger', 'trigger' => 'right'}
        )
        model.create()
        all = TriggerModel.all(group: GROUP, scope: SCOPE)
        expect(all.size).to eql(4)
      end
    end
  end
end
