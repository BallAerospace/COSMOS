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
require 'cosmos/operators/operator'

module Cosmos
  describe OperatorProcess do
    describe "start" do
      it "starts the process" do
        spy = spy('ChildProcess')
        expect(spy).to receive(:start)
        expect(ChildProcess).to receive(:build).with('ruby', 'filename.rb', 'DEFAULT__SERVICE__NAME').and_return(spy)

        capture_io do |stdout|
          op = OperatorProcess.new(['ruby', 'filename.rb', 'DEFAULT__SERVICE__NAME'], scope: 'DEFAULT')
          op.start
          expect(stdout.string).to include('filename.rb')
        end
      end
    end
  end
end
