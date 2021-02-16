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
      @proxy = double("ServerProxy")
      # Mock the server proxy to determine if it's received methods
      allow(ServerProxy).to receive(:new).and_return(@proxy)
      allow(@proxy).to receive(:shutdown)
      initialize_script()
    end

    after(:each) do
      shutdown_script()
    end

    describe "limits api calls" do
      %w(connected disconnected).each do |state|
        context(state) do
          it "#{state == 'connected' ? 'sends' : 'does not send'} to the api server" do
            disconnect_script() if state == 'disconnected'

            # These methods go through to the api server no matter if we're disconnected or not
            getters = %i(get_stale get_out_of_limits get_overall_limits_state limits_enabled? get_limits get_limits_groups get_limits_sets get_limits_set get_limits_events)
            getters.each do |method_name|
              expect(@proxy).to receive(method_name)
              send(method_name)
            end

            # These methods are simply logged in disconnect mode and don't go through
            setters = %i(enable_limits disable_limits set_limits enable_limits_group disable_limits_group set_limits_set)
            setters.each do |method_name|
              if state == 'connected'
                expect(@proxy).to receive(method_name)
              else
                expect(@proxy).to_not receive(method_name)
              end
              capture_io do |stdout|
                send(method_name, *method(method_name).parameters)
                if state == 'disconnected'
                  expect(stdout.string).to match(/DISCONNECT: #{method_name}/) #"
                end
              end
            end
          end
        end
      end
    end
  end
end
