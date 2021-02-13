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
require 'cosmos'
require 'cosmos/script'
require 'tempfile'

module Cosmos
  describe Script do
    before(:each) do
      allow_any_instance_of(Interface).to receive(:connected?).and_return(true)
      allow_any_instance_of(Interface).to receive(:disconnect)

      shutdown_script()
      initialize_script()
      sleep 0.1
    end

    after(:each) do
      shutdown_script()
      sleep(0.1)
    end

    describe "get_interface_names" do
      it "returns all interfaces" do
        expect(get_interface_names).to include("INST_INT")
      end
    end

    describe "connect_interface, disconnect_interface" do
      it "connects, disconnect and return the state of the interface CTS-3" do
        connect_interface("INST_INT")
        disconnect_interface("INST_INT")
      end
    end

    describe "get_interface_info" do
      it "returns interface info" do
        state, clients, tx_q_size, rx_q_size, bytes_tx, bytes_rx, cmd_cnt, tlm_cnt = get_interface_info("INST_INT")
        connect_interface("INST_INT")
        expect(state).to eql "CONNECTED"
        disconnect_interface("INST_INT")
        expect(clients).to be >= 0
        expect(tx_q_size).to be >= 0
        expect(rx_q_size).to be >= 0
        expect(bytes_tx).to be >= 0
        expect(bytes_rx).to be >= 0
        expect(cmd_cnt).to be >= 0
        expect(tlm_cnt).to be >= 0
      end
    end

    describe "get_router_info" do
      it "returns router info" do
        connect_router("PREIDENTIFIED_ROUTER")
        state, clients, tx_q_size, rx_q_size, bytes_tx, bytes_rx, pkts_rcvd, pkts_sent = get_router_info("PREIDENTIFIED_ROUTER")
        disconnect_router("PREIDENTIFIED_ROUTER")
        expect(state).to eql "CONNECTED"
        expect(clients).to be >= 0
        expect(tx_q_size).to be >= 0
        expect(rx_q_size).to be >= 0
        expect(bytes_tx).to be >= 0
        expect(bytes_rx).to be >= 0
        expect(pkts_rcvd).to be >= 0
        expect(pkts_sent).to be >= 0
      end
    end

    describe "get_target_info" do
      it "returns target info" do
        cmd_cnt, tlm_cnt = get_target_info("INST")
        expect(cmd_cnt).to be >= 0
        expect(tlm_cnt).to be >= 0
      end
    end

    describe "get_cmd_cnt" do
      it "returns cmd count" do
        expect(get_cmd_cnt("INST", "COLLECT")).to be >= 0
      end
    end

    describe "get_tlm_cnt" do
      it "returns tlm count" do
        expect(get_tlm_cnt("INST", "HEALTH_STATUS")).to be >= 0
      end
    end

    describe "connect_router, disconnect_router, get_router_names" do
      it "returns connect, disconnect, and list the routers CTS-11" do
        expect(get_router_names).to include("PREIDENTIFIED_ROUTER")
        connect_router("PREIDENTIFIED_ROUTER")
        disconnect_router("PREIDENTIFIED_ROUTER")
      end
    end
  end
end
