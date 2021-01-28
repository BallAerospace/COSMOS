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

module Cosmos
  # TODO: All store functionality is pretty much going out of store ... it will remain a shell for redis commands
  xdescribe Store do
    before(:each) do
      configure_store()
    end

    describe 'instance' do
      it 'returns the same object' do
        expect(Store.instance).equal?(Store.instance)
      end
    end

    # describe 'get_target' do
    #   it 'raises if target does not exist' do
    #     expect { Store.instance.get_target('NOTGT') }.to raise_error("Target 'NOTGT' does not exist")
    #   end

    #   it 'returns a target hash' do
    #     tgt = Store.instance.get_target('INST')
    #     expect(tgt).to be_a(Hash)
    #     expect(tgt['name']).to eql 'INST'
    #   end
    # end

    describe 'get_commands' do
      it 'raises if target does not exist' do
        expect { Store.instance.get_commands('NOTGT') }.to raise_error("Target 'NOTGT' does not exist")
      end

      it 'returns a command hash' do
        commands = Store.instance.get_commands('INST')
        expect(commands).to be_a(Array)
        expect(commands[0]['target_name']).to eql('INST')
        expect(commands[-1]['target_name']).to eql('INST')
      end
    end

    describe 'get_telemetry' do
      it 'raises if target does not exist' do
        expect { Store.instance.get_telemetry('NOTGT') }.to raise_error("Target 'NOTGT' does not exist")
      end

      it 'returns a telemetry hash' do
        telemetry = Store.instance.get_telemetry('INST')
        expect(telemetry).to be_a(Array)
        expect(telemetry[0]['target_name']).to eql('INST')
        expect(telemetry[-1]['target_name']).to eql('INST')
      end
    end
  end
end
