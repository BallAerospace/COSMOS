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
require 'cosmos/topics/autonomic_topic'
require 'cosmos/models/trigger_group_model'
require 'cosmos/models/trigger_model'
require 'cosmos/models/reaction_model'
require 'cosmos/microservices/reaction_microservice'

module Cosmos
  describe ReactionMicroservice do
    # Turn on tests here these tests can take up to three minutes so
    # if you want to test them set TEST = true
    TEST = false

    SCOPE = 'DEFAULT'.freeze
    GROUP = 'GROUP'.freeze

    def generate_custom_trigger_group(
      name: GROUP,
      color: '#ff0000'
    )
      return TriggerGroupModel.new(
        name: name,
        scope: SCOPE,
        color: color
      )
    end

    def generate_custom_trigger(
      name: 'foobar',
      left: {'type' => 'item', 'item' => 'POSX', 'packet' => 'ADCS', 'target' => 'INT'},
      operator: '<',
      right: {'type' => 'value', 'value' => 42}
    )
      return TriggerModel.new(
        name: name,
        scope: SCOPE,
        group: GROUP,
        left: left,
        operator: operator,
        right: right,
        dependents: []
      )
    end
  
    def generate_custom_reaction(
      name: 'foobar',
      description: 'another test',
      triggers: [{'name' => 'foobar', 'group' => GROUP}],
      actions: [{'type' => 'command', 'value' => 'TEST'}]
    )
      return ReactionModel.new(
        name: name,
        scope: SCOPE,
        description: description,
        snooze: 300,
        triggers: triggers,
        actions: actions
      )
    end

    def create_reaction
      generate_custom_trigger().create()
      r = generate_custom_reaction()
      r.create()
      return r
    end

    def generate_json_trigger(name:)
      t = generate_custom_trigger(name: name)
      t.create()
      return JSON.generate(t.as_json)
    end

    def generate_json_reaction(name:)
      r = generate_custom_reaction(name: name)
      r.create()
      return JSON.generate(r.as_json)
    end

    def setup_autonomic_topic
      allow(AutonomicTopic).to receive(:read_topics) { sleep 5 }.with([]).and_yield(
        'topic',
        'id-0',
        { 'type' => 'trigger', 'kind' => 'created', 'data' => generate_json_trigger(name: 'alpha') },
        nil
      ).and_yield(
        'topic',
        'id-1',
        { 'type' => 'reaction', 'kind' => 'created', 'data' => generate_json_reaction(name: 'beta') },
        nil
      ).and_yield(
        'topic',
        'id-2',
        { 'type' => 'log', 'kind' => 'event', 'data' => '{"name":"TEST"}' },
        nil
      ).and_yield(
        'topic',
        'id-3',
        { 'type' => 'log', 'kind' => 'error', 'data' => '{"name":"FOO"}' },
        nil
      ).and_yield(
        'topic',
        'id-4',
        { 'type' => 'trigger', 'kind' => 'event', 'data' => generate_json_reaction(name: 'beta') },
        nil
      ).and_yield(
        'topic',
        'id-5',
        { 'type' => 'log', 'kind' => 'error', 'data' => '{"name":"FOO"}' },
        nil
      ).and_yield(
        'topic',
        'id-6',
        { 'type' => 'trigger', 'kind' => 'deleted', 'data' => generate_json_reaction(name: 'alpha') },
        nil
      )
      allow(AutonomicTopic).to receive(:write_trigger) { sleep 1 }      
    end

    before(:each) do
      @redis = mock_redis()
      setup_system()
      generate_custom_trigger_group().create()
      generate_custom_trigger().create()
      allow(Cosmos::TriggerGroupModel).to receive(:deploy).and_return(nil)
      allow(Cosmos::TriggerGroupModel).to receive(:undeploy).and_return(nil)
      setup_autonomic_topic()
    end

    describe "ReactionMicroservice" do
      it "start and stop the ReactionMicroservice" do
        reaction_microservice = ReactionMicroservice.new("#{SCOPE}__COSMOS__REACTION")
        reaction_thread = Thread.new { reaction_microservice.run }
        sleep 2
        expect(reaction_thread.alive?).to be_truthy()
        expect(reaction_microservice.manager_thread.alive?).to be_truthy()
        reaction_microservice.manager.thread_pool.each do | worker |
          expect(worker.alive?).to be_truthy()
        end
        reaction_microservice.shutdown
        sleep 5
        expect(reaction_thread.alive?).to be_falsey()
        expect(reaction_microservice.manager_thread.alive?).to be_falsey()
        reaction_microservice.manager.thread_pool.each do | worker |
          expect(worker.alive?).to be_falsey()
        end
      end
    end if TEST

    describe "ReactionMicroservice" do
      it "validate that kit.triggers is populated with a trigger" do
        reaction_microservice = ReactionMicroservice.new("#{SCOPE}__COSMOS__REACTION")
        reaction_thread = Thread.new { reaction_microservice.run }
        sleep 4
        expect(
          reaction_microservice.share.reaction_base.get_reactions(trigger_name: 'foo').empty?
        ).to be_truthy()
        reaction_microservice.shutdown
        sleep 5
      end
    end if TEST

    describe "ReactionMicroservice" do
      it "validate that kit.triggers is populated with multiple triggers" do
        create_reaction()
        reaction_microservice = ReactionMicroservice.new("#{SCOPE}__COSMOS__REACTION")
        reaction_thread = Thread.new { reaction_microservice.run }
        sleep 4
        expect(
          reaction_microservice.share.reaction_base.get_reactions(trigger_name: 'foobar').empty?
        ).to be_falsey()
        reaction_microservice.shutdown
        sleep 5
      end
    end if TEST

  end
end
