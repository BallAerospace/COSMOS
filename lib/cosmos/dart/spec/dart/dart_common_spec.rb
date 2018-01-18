# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'rails_helper'
require 'dart_common'

describe DartCommon do
  let(:common) { Object.new.extend(DartCommon) }

  describe "sync_targets_and_packets" do
    it "configures the database" do
      targets = Cosmos::System.telemetry.all.keys.sort
      expect(targets).to eql Cosmos::System.commands.all.keys.sort

      # Put all the known targets and packets into the DB
      common.sync_targets_and_packets

      # Verify the targets
      Target.all.order(:name).each_with_index do |target, i|
        expect(target.name).to eq targets[i]
      end
      # Verify the telemetry packets
      Cosmos::System.telemetry.all.each do |target_name, packets|
        target = Target.find_by_name(target_name)
        expect(target.name).to eq target_name
        packets.each do |name, packet|
          pkt = Packet.where({target: target, name: name, is_tlm: true}).first
          expect(pkt.name).to eq name
          expect(pkt.is_tlm).to eq true
          expect(pkt.target.name).to eq target_name
        end
      end
      # Verify the command packets
      Cosmos::System.commands.all.each do |target_name, packets|
        target = Target.find_by_name(target_name)
        expect(target.name).to eq target_name
        packets.each do |name, packet|
          pkt = Packet.where({target: target, name: name, is_tlm: false}).first
          expect(pkt.name).to eq name
          expect(pkt.is_tlm).to eq false
          expect(pkt.target.name).to eq target_name
        end
      end

      num_tgts = Target.all.length
      tgt_created_at = Target.first.created_at
      num_pkts = Packet.all.length
      pkt_created_at = Packet.first.created_at

      # Try to add the known targets and packets into the DB again
      common.sync_targets_and_packets
      # Verify nothing was added
      expect(Target.all.length).to eq num_tgts
      expect(Packet.all.length).to eq num_pkts
      expect(Target.first.created_at).to eq tgt_created_at
      expect(Packet.first.created_at).to eq pkt_created_at
    end
  end
end
