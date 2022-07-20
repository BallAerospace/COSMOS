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
require 'openc3/topics/autonomic_topic'
require 'openc3/models/trigger_group_model'
require 'openc3/models/trigger_model'
require 'openc3/microservices/trigger_group_microservice'

module OpenC3
  describe TriggerGroupMicroservice do
    # Turn on tests here these tests can take up to three minutes so
    # if you want to test them set TGMI_TEST = true
    TGMI_TEST = false

    TGMI_GROUP = 'GROUP'.freeze

    def generate_trigger_group_model(
      name: TGMI_GROUP,
      color: '#ff0000'
    )
      return TriggerGroupModel.new(
        name: name,
        scope: $openc3_scope,
        color: color
      )
    end

    def generate_trigger(
      name: 'foobar',
      left: {'type' => 'item', 'target' => 'INST', 'packet' => 'ADCS', 'item' => 'POSX'},
      operator: '<',
      right: {'type' => 'value', 'value' => 42}
    )
      return TriggerModel.new(
        name: name,
        scope: $openc3_scope,
        group: TGMI_GROUP,
        left: left,
        operator: operator,
        right: right,
        dependents: []
      )
    end

    def generate_json_trigger(name:)
      t = generate_trigger(name: name)
      t.create()
      return JSON.generate(t.as_json(:allow_nan => true))
    end

    def generate_trigger_dependent_model
      generate_trigger(name: 'A').create()
      generate_trigger(name: 'B').create()
      c = generate_trigger(
        name: 'C',
        left: {'type' => 'trigger', 'trigger' => 'A'},
        operator: 'AND',
        right: {'type' => 'trigger', 'trigger' => 'B'}
      )
      c.create()
      return c
    end

    def setup_autonomic_topic
      allow(AutonomicTopic).to receive(:read_topics) { sleep 5 }.and_yield(
        'topic',
        'id-0',
        { 'type' => 'trigger', 'kind' => 'created', 'data' => generate_json_trigger(name: 'alpha') },
        nil
      ).and_yield(
        'topic',
        'id-1',
        { 'type' => 'trigger', 'kind' => 'created', 'data' => generate_json_trigger(name: 'beta') },
        nil
      ).and_yield(
        'topic',
        'id-2',
        { 'type' => 'reaction', 'kind' => 'enabled', 'data' => '{"name":"TEST"}' },
        nil
      ).and_yield(
        'topic',
        'id-3',
        { 'type' => 'reaction', 'kind' => 'disabled', 'data' => '{"name":"FOO"}' },
        nil
      ).and_yield(
        'topic',
        'id-4',
        { 'type' => 'trigger', 'kind' => 'updated', 'data' => generate_json_trigger(name: 'alpha') },
        nil
      ).and_yield(
        'topic',
        'id-5',
        { 'type' => 'trigger', 'kind' => 'deleted', 'data' => generate_json_trigger(name: 'alpha') },
        nil
      )
      allow(AutonomicTopic).to receive(:write_trigger) { sleep 1 }      
    end

    def generate_packet_hash
      packet_value = rand(1000)
      return { 
        'time' => now = Time.now.to_i * 10_000_000,
        'stored' => true,
        'target_name' => 'TARGET',
        'packet_name' => 'PACKET',
        'received_count' => rand(100),
        'json_data' => JSON.generate({
          'POSX' => packet_value,
          'POSX__C' => "#{packet_value} M",
          'POSX__F' => "#{packet_value} M",
          'POSX__U' => 'METERS',
        }) 
      }
    end

    def setup_decom_topic
      allow(Topic).to receive(:read_topics) { sleep 5 }.and_yield(
        'topic',
        'id-1',
        generate_packet_hash,
        nil
      ).and_yield(
        'topic',
        'id-2',
        generate_packet_hash,
        nil
      ).and_yield(
        'topic',
        'id-3',
        generate_packet_hash,
        nil
      ).and_yield(
        'topic',
        'id-4',
        generate_packet_hash,
        nil
      ).and_yield(
        'topic',
        'id-5',
        generate_packet_hash,
        nil
      )
    end      

    before(:each) do
      @redis = mock_redis()
      setup_system()
      generate_trigger_group_model().create()
      setup_autonomic_topic()
      setup_decom_topic()
    end

    describe "TriggerGroupMicroservice" do
      it "start and stop the TriggerGroupMicroservice" do
        trigger_microservice = TriggerGroupMicroservice.new("#{$openc3_scope}__TRIGGER__#{TGMI_GROUP}")
        trigger_thread = Thread.new { trigger_microservice.run }
        sleep 2
        expect(trigger_thread.alive?).to be_truthy()
        expect(trigger_microservice.manager_thread.alive?).to be_truthy()
        for worker in trigger_microservice.manager.thread_pool do
          expect(worker.alive?).to be_truthy()
        end
        trigger_microservice.shutdown
        sleep 5
        expect(trigger_thread.alive?).to be_falsey()
        expect(trigger_microservice.manager_thread.alive?).to be_falsey()
        for worker in trigger_microservice.manager.thread_pool do
          expect(worker.alive?).to be_falsey()
        end
      end
    end if TGMI_TEST

    describe "TriggerGroupMicroservice" do
      it "validate that kit.triggers is populated with a trigger" do
        trigger_microservice = TriggerGroupMicroservice.new("#{$openc3_scope}__TRIGGER__#{TGMI_GROUP}")
        trigger_thread = Thread.new { trigger_microservice.run }
        sleep 4
        expect(trigger_microservice.share.trigger_base.triggers.empty?).to be_falsey()
        trigger_microservice.shutdown
        sleep 5
      end
    end if TGMI_TEST

    describe "TriggerGroupMicroservice" do
      it "validate that kit.triggers is populated with multiple triggers" do
        generate_trigger_dependent_model()
        trigger_microservice = TriggerGroupMicroservice.new("#{$openc3_scope}__TRIGGER__#{TGMI_GROUP}")
        trigger_thread = Thread.new { trigger_microservice.run }
        sleep 4
        expect(trigger_microservice.share.trigger_base.triggers.empty?).to be_falsey()
        trigger_microservice.shutdown
        sleep 5
      end
    end if TGMI_TEST

    describe "TriggerGroupMicroservice" do
      it "validate that kit.triggers is populated with a second layer dependent trigger" do
        generate_trigger_dependent_model()
        d = generate_trigger(
          name: 'D',
          left: {'type' => 'trigger', 'trigger' => 'B'},
          operator: 'AND',
          right: {'type' => 'trigger', 'trigger' => 'C'}
        )
        d.create()
        trigger_microservice = TriggerGroupMicroservice.new("#{$openc3_scope}__TRIGGER__#{TGMI_GROUP}")
        trigger_thread = Thread.new { trigger_microservice.run }
        sleep 4
        expect(trigger_microservice.share.trigger_base.triggers.empty?).to be_falsey()
        trigger_microservice.shutdown
        sleep 5
      end
    end if TGMI_TEST

    describe "TriggerGroupMicroservice" do
      it "validate that kit.triggers is populated with a third layer dependent trigger" do
        generate_trigger_dependent_model()
        d = generate_trigger(
          name: 'D',
          left: {'type' => 'trigger', 'trigger' => 'B'},
          operator: 'AND',
          right: {'type' => 'trigger', 'trigger' => 'C'}
        )
        d.create()
        e = generate_trigger(
          name: 'E',
          left: {'type' => 'trigger', 'trigger' => 'A'},
          operator: 'AND',
          right: {'type' => 'trigger', 'trigger' => 'D'}
        )
        e.create()
        trigger_microservice = TriggerGroupMicroservice.new("#{$openc3_scope}__TRIGGER__#{TGMI_GROUP}")
        trigger_thread = Thread.new { trigger_microservice.run }
        sleep 4
        expect(trigger_microservice.share.trigger_base.triggers.empty?).to be_falsey()
        trigger_microservice.shutdown
        sleep 5
      end
    end if TGMI_TEST
  end
end
